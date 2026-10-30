import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MailerService } from './mailer.service';

export interface AffiliateValidationResult {
  isAffiliated: boolean;
  fullName: string;
  affiliationType: string; // 'SEGURO_GENERAL', 'JUBILADO', 'VOLUNTARIO', 'CAMPESINO'
  hasActiveArrears: boolean; // Mora patronal / cesantía
  statusDescription: string;
}

export interface MedicalReferralValidationResult {
  hasValidReferral: boolean;
  referralId?: string;
  sourceSpecialty?: string;
  targetSpecialtyCode: string;
  expiresAt?: Date;
  status: 'ACTIVE' | 'EXPIRED' | 'NOT_FOUND' | 'USED';
}

@Injectable()
export class IessIntegrationService {
  private readonly logger = new Logger(IessIntegrationService.name);
  private failureRate: number;

  constructor(
    private configService: ConfigService,
    private mailerService: MailerService,
  ) {
    this.failureRate = parseFloat(this.configService.get<string>('IESS_MOCK_FAILURE_RATE') || '0.0');
  }

  /**
   * Simulación del servicio institucional del IESS para validar el estado de afiliación
   * (Cumplimiento RF08 / R08)
   */
  async validateAffiliateStatus(idCard: string): Promise<AffiliateValidationResult> {
    this.logger.log(`[MOCK_IESS] Validando afiliación para cédula: ${idCard.substring(0, 6)}****`);

    // Simulación de resiliencia / Circuit Breaker (R08)
    if (Math.random() < this.failureRate) {
      this.logger.error('[MOCK_IESS] Error simulado de conexión con el sistema central del IESS');
      throw new ServiceUnavailableException('El servicio institucional del IESS no está disponible temporalmente. Intente nuevamente.');
    }

    // Regla simulada: Cédulas que terminen en "99" se consideran inactivas o sin aportes
    if (idCard.endsWith('99')) {
      return {
        isAffiliated: false,
        fullName: 'Ciudadano No Afiliado Simulado',
        affiliationType: 'NINGUNA',
        hasActiveArrears: true,
        statusDescription: 'El afiliado no registra aportaciones activas ni cobertura médica vigente en el IESS.',
      };
    }

    return {
      isAffiliated: true,
      fullName: 'Afiliado Titular Validado',
      affiliationType: 'SEGURO_GENERAL_OBLIGATORIO',
      hasActiveArrears: false,
      statusDescription: 'Afiliación activa con cobertura de salud integral.',
    };
  }

  /**
   * Simulación de verificación de derivaciones médicas para especialidades de 2do y 3er nivel (RF01, RF08)
   */
  async validateMedicalReferral(idCard: string, specialtyCode: string): Promise<MedicalReferralValidationResult> {
    this.logger.log(`[MOCK_IESS] Verificando derivación para especialidad ${specialtyCode} y paciente ${idCard.substring(0, 6)}****`);

    // Las especialidades de atención primaria no requieren derivación
    if (specialtyCode === 'MED-GEN' || specialtyCode === 'PED-001' || specialtyCode === 'GYN-001') {
      return {
        hasValidReferral: true,
        targetSpecialtyCode: specialtyCode,
        status: 'ACTIVE',
      };
    }

    // Regla simulada: Paciente con cédula terminada en "51" o "39" cuenta con derivación activa
    const hasReferral = idCard.endsWith('51') || idCard.endsWith('39') || idCard.endsWith('01');

    if (!hasReferral) {
      return {
        hasValidReferral: false,
        targetSpecialtyCode: specialtyCode,
        status: 'NOT_FOUND',
      };
    }

    return {
      hasValidReferral: true,
      referralId: `DERIV-${specialtyCode}-${idCard.substring(6)}`,
      sourceSpecialty: 'MED-GEN',
      targetSpecialtyCode: specialtyCode,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // Válida por 30 días
      status: 'ACTIVE',
    };
  }

  /**
   * Envía una notificación administrativa real al afiliado vía Nodemailer / Gmail SMTP (RF07 / R11).
   * No incluye datos clínicos ni número de cédula.
   */
  async sendAdministrativeNotification(
    recipientContact: { email: string; phone?: string },
    details: { patientName: string; appointmentDate: string; facilityName: string; doctorName: string; action: 'CONFIRMED' | 'CANCELLED' | 'RESCHEDULED' },
  ): Promise<boolean> {
    this.logger.log(
      `[NOTIFICATION] Enviando aviso administrativo por correo a ${recipientContact.email} — acción: ${details.action}`,
    );

    const sent = await this.mailerService.sendAppointmentNotification(
      recipientContact.email,
      details,
    );

    if (!sent) {
      this.logger.warn(
        `[NOTIFICATION] Fallo al enviar correo a ${recipientContact.email}. La operación de cita continuará.`,
      );
    }

    return sent;
  }

  /**
   * Envía las credenciales temporales por correo electrónico
   */
  async sendTemporaryCredentials(
    email: string,
    fullName: string,
    temporaryPassword: string,
    expiresInMinutes: number = 15,
  ): Promise<boolean> {
    this.logger.log(
      `[NOTIFICATION] Enviando contraseña temporal por correo a ${email}`,
    );

    return this.mailerService.sendTemporaryPasswordNotification(
      email,
      fullName,
      temporaryPassword,
      expiresInMinutes,
    );
  }
}

