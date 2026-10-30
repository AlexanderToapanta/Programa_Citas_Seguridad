import {
  Controller,
  Post,
  Get,
  Query,
  Patch,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { AppointmentsService } from './appointments.service';
import { BookAppointmentDto, RescheduleAppointmentDto, CancelAppointmentDto } from './dto/appointment.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Gestión de Citas Médicas (RF01, RF03, RF06)')
@Controller('appointments')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class AppointmentsController {
  constructor(private readonly appointmentsService: AppointmentsService) {}

  @Post()
  @ApiOperation({
    summary: 'Reservar cita médica con validaciones de cupo, cita activa única, inasistencias y derivaciones',
  })
  @ApiResponse({ status: 201, description: 'Cita reservada exitosamente' })
  @ApiResponse({ status: 409, description: 'Cupo ocupado o usuario ya mantiene una cita activa' })
  @ApiResponse({ status: 403, description: 'Bloqueado por 3 inasistencias, falta de autorización o falta de derivación' })
  async bookAppointment(@CurrentUser() user: any, @Body() dto: BookAppointmentDto) {
    return this.appointmentsService.bookAppointment(user, dto);
  }

  @Get('my')
  @ApiOperation({
    summary: 'Consultar citas propias o de familiares representados (Protección IDOR/BOLA aplicada)',
  })
  async findMyAppointments(@CurrentUser() user: any, @Query('date') date?: string) {
    return this.appointmentsService.findMyAppointments(user, date);
  }

  @Patch(':id/reschedule')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Reprogramar una cita médica existente (Permitido hasta 8 horas antes del horario)',
  })
  @ApiResponse({ status: 200, description: 'Cita reprogramada con éxito' })
  @ApiResponse({ status: 400, description: 'Menos de 8 horas de anticipación' })
  @ApiResponse({ status: 403, description: 'Intento de modificar una cita ajena no autorizada' })
  async rescheduleAppointment(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() dto: RescheduleAppointmentDto,
  ) {
    return this.appointmentsService.rescheduleAppointment(id, user, dto);
  }

  @Patch(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Cancelar cita médica antes de su inicio sin límite fijo de veces',
  })
  @ApiResponse({ status: 200, description: 'Cita cancelada y cupo liberado' })
  @ApiResponse({ status: 400, description: 'La cita ya inició o ya fue cancelada' })
  async cancelAppointment(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() dto: CancelAppointmentDto,
  ) {
    return this.appointmentsService.cancelAppointment(id, user, dto);
  }
}

