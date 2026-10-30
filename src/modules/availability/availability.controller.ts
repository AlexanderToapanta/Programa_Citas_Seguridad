import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { PrismaService } from '../../prisma/prisma.service';
import { Public } from '../../common/decorators/roles.decorator';

@ApiTags('Disponibilidad de Cupos y Horarios (RF01)')
@Controller('availability')
export class AvailabilityController {
  constructor(private prisma: PrismaService) {}

  @Public()
  @Get('slots')
  @ApiOperation({ summary: 'Consultar cupos disponibles filtrados por especialidad, establecimiento y fecha' })
  @ApiQuery({ name: 'specialtyId', required: false, type: String })
  @ApiQuery({ name: 'facilityId', required: false, type: String })
  @ApiQuery({ name: 'date', required: false, type: String, description: 'Fecha en formato YYYY-MM-DD' })
  async getAvailableSlots(
    @Query('specialtyId') specialtyId?: string,
    @Query('facilityId') facilityId?: string,
    @Query('date') date?: string,
  ) {
    const whereClause: any = {
      isAvailable: true,
      startTime: {
        gte: new Date(), // Solo horarios a futuro
      },
    };

    if (date) {
      const parsedDate = new Date(date);
      parsedDate.setHours(0, 0, 0, 0);
      const nextDay = new Date(parsedDate);
      nextDay.setDate(nextDay.getDate() + 1);

      whereClause.startTime = {
        gte: parsedDate > new Date() ? parsedDate : new Date(),
        lt: nextDay,
      };
    }

    if (specialtyId || facilityId) {
      whereClause.doctor = {};
      if (specialtyId) {
        whereClause.doctor.specialtyId = specialtyId;
      }
      if (facilityId) {
        whereClause.doctor.facilityId = facilityId;
      }
    }

    return this.prisma.appointmentSlot.findMany({
      where: whereClause,
      include: {
        doctor: {
          select: {
            id: true,
            licenseNumber: true,
            user: { select: { fullName: true } },
            specialty: { select: { id: true, code: true, name: true, requiresReferral: true } },
            facility: { select: { id: true, code: true, name: true, city: true } },
          },
        },
      },
      orderBy: { startTime: 'asc' },
      take: 100, // Limitar para mitigar DoS de capa 7 (R02)
    });
  }
}

