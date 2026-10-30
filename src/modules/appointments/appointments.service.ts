import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { IessIntegrationService } from '../integrations/iess-integration.service';
import { BookAppointmentDto, RescheduleAppointmentDto, CancelAppointmentDto } from './dto/appointment.dto';
import { AppointmentStatus, RoleType, AuthorizationStatus } from '@prisma/client';

@Injectable()
export class AppointmentsService {
  private readonly logger = new Logger(AppointmentsService.name);

  constructor(
    private prisma: PrismaService,
    private iessService: IessIntegrationService,
  ) {}

  /**
   * Reserva atómica de cita médica con reglas institucionales completas:
   * 1. Cupo disponible con bloqueo concurrente (R07)
   * 2. Máximo una cita activa por afiliado (RF01)
   * 3. Control de 3 inasistencias injustificadas en los últimos 90 días (RF01)
   * 4. Validación de representación familiar si agenda para un tercero (RF04 / R04)
   * 5. Verificación de derivación médica si la especialidad lo exige (RF01, RF08)
   */
  async bookAppointment(currentUser: any, dto: BookAppointmentDto) {
    let targetAffiliateId = currentUser.id;
    let targetAffiliateIdCard = currentUser.idCard;

    // A. Gestión de citas por familiar autorizado o recepción (RF04 / RF06)
    if (dto.affiliateIdCard && dto.affiliateIdCard !== currentUser.idCard) {
      const targetUser = await this.prisma.user.findUnique({
        where: { idCard: dto.affiliateIdCard },
      });
      if (!targetUser) {
        throw new NotFoundException('El afiliado beneficiario no se encuentra registrado en el sistema');
      }

      const isStaff = currentUser.roles.some((r: string) =>
        [RoleType.ADMIN, RoleType.RECEPTIONIST].includes(r as any),
      );

      if (!isStaff) {
        // Verificar autorización familiar activa y vigente en base de datos (R04 - IDOR)
        const authorization = await this.prisma.familyAuthorization.findFirst({
          where: {
            principalUserId: targetUser.id,
            representativeUserId: currentUser.id,
            status: AuthorizationStatus.ACTIVE,
            validUntil: { gte: new Date() },
          },
        });

        if (!authorization) {
          throw new ForbiddenException(
            'Acceso denegado: No posee una autorización familiar válida y vigente para agendar turnos de este afiliado.',
          );
        }
      }

      targetAffiliateId = targetUser.id;
      targetAffiliateIdCard = targetUser.idCard;
    }

    // B. Regla Institucional: Verificar 3 inasistencias injustificadas en 90 días (RF01)
    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

    const noShowCount = await this.prisma.appointment.count({
      where: {
        affiliateId: targetAffiliateId,
        status: AppointmentStatus.NO_SHOW,
        scheduledAt: { gte: ninetyDaysAgo },
      },
    });

    if (noShowCount >= 3) {
      throw new ForbiddenException(
        'Reserva en línea suspendida: El afiliado registra 3 inasistencias injustificadas en los últimos 90 días. Debe acudir presencialmente para una revisión administrativa.',
      );
    }

    // C. Regla Institucional: Máximo una cita activa por afiliado (RF01)
    const activeAppointment = await this.prisma.appointment.findFirst({
      where: {
        affiliateId: targetAffiliateId,
        status: { in: [AppointmentStatus.SCHEDULED, AppointmentStatus.RESCHEDULED] },
        scheduledAt: { gte: new Date() },
      },
      include: {
        specialty: true,
        facility: true,
      },
    });

    if (activeAppointment) {
      throw new ConflictException(
        `El afiliado ya mantiene una cita activa para ${activeAppointment.specialty.name} en ${activeAppointment.facility.name} programada para el ${activeAppointment.scheduledAt.toISOString()}. Cancele o finalice la anterior antes de reservar una nueva.`,
      );
    }

    // D. Transacción atómica en PostgreSQL con control estricto de concurrencia (R07)
    return await this.prisma.$transaction(async (tx) => {
      // Bloquear e inspeccionar slot
      const slot = await tx.appointmentSlot.findUnique({
        where: { id: dto.slotId },
        include: {
          doctor: {
            include: {
              specialty: true,
              facility: true,
              user: true,
            },
          },
        },
      });

      if (!slot) {
        throw new NotFoundException('El cupo de atención especificado no existe');
      }

      if (!slot.isAvailable || slot.startTime < new Date()) {
        throw new ConflictException('El horario seleccionado ya no está disponible o ha expirado');
      }

      // E. Validar derivación médica si la especialidad lo exige (RF01, RF08)
      if (slot.doctor.specialty.requiresReferral) {
        const referralCheck = await this.iessService.validateMedicalReferral(
          targetAffiliateIdCard,
          slot.doctor.specialty.code,
        );
        if (!referralCheck.hasValidReferral) {
          throw new ForbiddenException(
            `La especialidad ${slot.doctor.specialty.name} requiere una derivación médica activa de Medicina General. El afiliado no registra derivación vigente.`,
          );
        }
      }

      // 1. Marcar cupo como ocupado (Row level concurrency control)
      const updatedSlot = await tx.appointmentSlot.updateMany({
        where: {
          id: slot.id,
          isAvailable: true,
          version: slot.version,
        },
        data: {
          isAvailable: false,
          version: { increment: 1 },
        },
      });

      if (updatedSlot.count === 0) {
        throw new ConflictException('Conflicto de concurrencia: Otro usuario reservó este cupo simultáneamente.');
      }

      // 2. Crear o reutilizar registro de cita médica para el slot
      // Si el slot ya tuvo una cita cancelada previa, se actualiza para preservar unicidad del slot_id
      const existingApptOnSlot = await tx.appointment.findUnique({
        where: { slotId: slot.id },
      });

      let appointment;
      if (existingApptOnSlot) {
        appointment = await tx.appointment.update({
          where: { id: existingApptOnSlot.id },
          data: {
            affiliateId: targetAffiliateId,
            bookedByUserId: currentUser.id,
            specialtyId: slot.doctor.specialtyId,
            facilityId: slot.doctor.facilityId,
            doctorId: slot.doctorId,
            scheduledAt: slot.startTime,
            status: AppointmentStatus.SCHEDULED,
            cancellationReason: null,
          },
          include: {
            specialty: { select: { name: true, code: true } },
            facility: { select: { name: true, address: true, city: true } },
            doctor: { select: { user: { select: { fullName: true } } } },
            affiliate: { select: { fullName: true, email: true, phoneNumber: true } },
          },
        });
      } else {
        appointment = await tx.appointment.create({
          data: {
            affiliateId: targetAffiliateId,
            bookedByUserId: currentUser.id,
            specialtyId: slot.doctor.specialtyId,
            facilityId: slot.doctor.facilityId,
            doctorId: slot.doctorId,
            slotId: slot.id,
            scheduledAt: slot.startTime,
            status: AppointmentStatus.SCHEDULED,
          },
          include: {
            specialty: { select: { name: true, code: true } },
            facility: { select: { name: true, address: true, city: true } },
            doctor: { select: { user: { select: { fullName: true } } } },
            affiliate: { select: { fullName: true, email: true, phoneNumber: true } },
          },
        });
      }

      // 3. Emitir notificación administrativa (RF07)
      await this.iessService.sendAdministrativeNotification(
        { email: appointment.affiliate.email, phone: appointment.affiliate.phoneNumber },
        {
          patientName: appointment.affiliate.fullName,
          appointmentDate: appointment.scheduledAt.toISOString(),
          facilityName: appointment.facility.name,
          doctorName: appointment.doctor.user.fullName,
          action: 'CONFIRMED',
        },
      );

      return {
        message: 'Cita médica confirmada exitosamente',
        appointment: {
          id: appointment.id,
          scheduledAt: appointment.scheduledAt,
          specialty: appointment.specialty.name,
          facility: appointment.facility.name,
          facilityAddress: appointment.facility.address,
          doctor: appointment.doctor.user.fullName,
          patientName: appointment.affiliate.fullName,
          status: appointment.status,
        },
      };
    });
  }

  /**
   * Consulta de citas con protección estricta contra IDOR/BOLA (R04) y mínimo privilegio (RF06)
   */
  async findMyAppointments(currentUser: any, queryDate?: string) {
    const isDoctor = currentUser.roles.includes(RoleType.DOCTOR);
    const isStaff = currentUser.roles.some((r: string) =>
      [RoleType.ADMIN, RoleType.RECEPTIONIST, RoleType.SUPPORT].includes(r as any),
    );

    if (isDoctor) {
      // Médicos únicamente ven citas asignadas a su atención (RF06)
      const doctorProfile = await this.prisma.doctor.findUnique({
        where: { userId: currentUser.id },
      });
      if (!doctorProfile) {
        return [];
      }
      return this.prisma.appointment.findMany({
        where: { doctorId: doctorProfile.id },
        include: {
          specialty: true,
          facility: true,
          affiliate: { select: { fullName: true, idCard: true, phoneNumber: true } },
        },
        orderBy: { scheduledAt: 'asc' },
      });
    }

    if (isStaff) {
      // Recepción / Admin / Soporte ven listado operativo sin expedientes clínicos (RF03, RF06)
      let dateFilter: any = {};
      if (queryDate) {
        const start = new Date(queryDate + 'T00:00:00.000Z');
        const end = new Date(queryDate + 'T23:59:59.999Z');
        dateFilter = { scheduledAt: { gte: start, lte: end } };
      }
      return this.prisma.appointment.findMany({
        where: dateFilter,
        include: {
          specialty: true,
          facility: true,
          doctor: { select: { user: { select: { fullName: true } } } },
          affiliate: { select: { fullName: true, idCard: true } },
        },
        orderBy: { scheduledAt: 'desc' },
        take: 100,
      });
    }

    // Afiliado o familiar autorizado: buscar citas propias y citas de personas representadas
    const authorizedRepresentedIds = (
      await this.prisma.familyAuthorization.findMany({
        where: {
          representativeUserId: currentUser.id,
          status: AuthorizationStatus.ACTIVE,
          validUntil: { gte: new Date() },
        },
        select: { principalUserId: true },
      })
    ).map((a) => a.principalUserId);

    return this.prisma.appointment.findMany({
      where: {
        affiliateId: { in: [currentUser.id, ...authorizedRepresentedIds] },
      },
      include: {
        specialty: true,
        facility: true,
        doctor: { select: { user: { select: { fullName: true } } } },
        affiliate: { select: { id: true, fullName: true, idCard: true } },
      },
      orderBy: { scheduledAt: 'desc' },
    });
  }

  /**
   * Reprogramación de citas:
   * Regla de negocio: Permitido hasta 8 horas antes del inicio (RF01)
   */
  async rescheduleAppointment(appointmentId: string, currentUser: any, dto: RescheduleAppointmentDto) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: { affiliate: true, slot: true },
    });

    if (!appointment) {
      throw new NotFoundException('Cita no encontrada');
    }

    // Control de Autorización (R04 - IDOR)
    await this.validateOwnershipOrRepresentation(appointment.affiliateId, currentUser);

    if (appointment.status !== AppointmentStatus.SCHEDULED && appointment.status !== AppointmentStatus.RESCHEDULED) {
      throw new BadRequestException('Solo se pueden reprogramar citas en estado activo');
    }

    // Regla de las 8 horas (RF01)
    const hoursDiff = (appointment.scheduledAt.getTime() - Date.now()) / (1000 * 60 * 60);
    if (hoursDiff < 8) {
      throw new BadRequestException(
        'Plazo excedido: Las citas solo pueden reprogramarse con al menos 8 horas de anticipación. Para cambios excepcionales comuníquese con el establecimiento.',
      );
    }

    // Transacción de reprogramación
    return await this.prisma.$transaction(async (tx) => {
      // 1. Obtener y verificar nuevo slot
      const newSlot = await tx.appointmentSlot.findUnique({
        where: { id: dto.newSlotId },
        include: {
          doctor: { include: { specialty: true, facility: true, user: true } },
        },
      });

      if (!newSlot || !newSlot.isAvailable || newSlot.startTime < new Date()) {
        throw new ConflictException('El nuevo horario seleccionado no está disponible');
      }

      // 2. Liberar el slot anterior
      await tx.appointmentSlot.update({
        where: { id: appointment.slotId },
        data: { isAvailable: true },
      });

      // 3. Ocupar el nuevo slot
      await tx.appointmentSlot.update({
        where: { id: newSlot.id },
        data: { isAvailable: false },
      });

      // 4. Actualizar la cita
      const updated = await tx.appointment.update({
        where: { id: appointment.id },
        data: {
          slotId: newSlot.id,
          doctorId: newSlot.doctorId,
          specialtyId: newSlot.doctor.specialtyId,
          facilityId: newSlot.doctor.facilityId,
          scheduledAt: newSlot.startTime,
          status: AppointmentStatus.RESCHEDULED,
        },
        include: {
          specialty: true,
          facility: true,
          doctor: { select: { user: { select: { fullName: true } } } },
        },
      });

      // Notificación administrativa
      await this.iessService.sendAdministrativeNotification(
        { email: appointment.affiliate.email, phone: appointment.affiliate.phoneNumber },
        {
          patientName: appointment.affiliate.fullName,
          appointmentDate: updated.scheduledAt.toISOString(),
          facilityName: updated.facility.name,
          doctorName: updated.doctor.user.fullName,
          action: 'RESCHEDULED',
        },
      );

      return {
        message: 'Cita reprogramada con éxito',
        appointment: updated,
      };
    });
  }

  /**
   * Cancelación de citas:
   * Regla de negocio: Permitido antes del inicio de la cita sin límite fijo de veces (RF01)
   */
  async cancelAppointment(appointmentId: string, currentUser: any, dto: CancelAppointmentDto) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: { affiliate: true, slot: true, facility: true, doctor: { include: { user: true } } },
    });

    if (!appointment) {
      throw new NotFoundException('Cita no encontrada');
    }

    // Control de Autorización (R04 - IDOR)
    await this.validateOwnershipOrRepresentation(appointment.affiliateId, currentUser);

    if (appointment.status === AppointmentStatus.CANCELLED) {
      throw new BadRequestException('La cita ya se encuentra cancelada');
    }

    // Regla: Cancelar antes del inicio
    if (appointment.scheduledAt <= new Date()) {
      throw new BadRequestException('No es posible cancelar una cita médica posterior a su hora de inicio');
    }

    return await this.prisma.$transaction(async (tx) => {
      // Liberar slot
      await tx.appointmentSlot.update({
        where: { id: appointment.slotId },
        data: { isAvailable: true },
      });

      // Actualizar estado de cita
      const cancelled = await tx.appointment.update({
        where: { id: appointment.id },
        data: {
          status: AppointmentStatus.CANCELLED,
          cancellationReason: dto.reason,
        },
      });

      // Notificación administrativa
      await this.iessService.sendAdministrativeNotification(
        { email: appointment.affiliate.email, phone: appointment.affiliate.phoneNumber },
        {
          patientName: appointment.affiliate.fullName,
          appointmentDate: appointment.scheduledAt.toISOString(),
          facilityName: appointment.facility.name,
          doctorName: appointment.doctor.user.fullName,
          action: 'CANCELLED',
        },
      );

      return {
        message: 'Cita médica cancelada correctamente',
        appointment: cancelled,
      };
    });
  }

  /**
   * Validación de propiedad o representación autorizada (Mitigación IDOR / BOLA - R04)
   */
  private async validateOwnershipOrRepresentation(affiliateId: string, currentUser: any) {
    if (currentUser.id === affiliateId) {
      return true;
    }

    const isStaff = currentUser.roles.some((r: string) =>
      [RoleType.ADMIN, RoleType.RECEPTIONIST].includes(r as any),
    );
    if (isStaff) {
      return true;
    }

    const auth = await this.prisma.familyAuthorization.findFirst({
      where: {
        principalUserId: affiliateId,
        representativeUserId: currentUser.id,
        status: AuthorizationStatus.ACTIVE,
        validUntil: { gte: new Date() },
      },
    });

    if (!auth) {
      throw new ForbiddenException('Acceso denegado: No cuenta con autorización para gestionar citas de este paciente');
    }

    return true;
  }
}

