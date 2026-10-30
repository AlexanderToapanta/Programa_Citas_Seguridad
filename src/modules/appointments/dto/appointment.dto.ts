import { IsString, IsNotEmpty, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class BookAppointmentDto {
  @ApiProperty({ description: 'ID del cupo de atención seleccionado', example: 'uuid-del-slot' })
  @IsString()
  @IsNotEmpty()
  slotId: string;

  @ApiProperty({
    description: 'Cédula o ID del afiliado beneficiario (si un familiar autorizado reserva por él). Opcional si reserva para sí mismo.',
    required: false,
    example: '1708451239',
  })
  @IsOptional()
  @IsString()
  affiliateIdCard?: string;
}

export class RescheduleAppointmentDto {
  @ApiProperty({ description: 'ID del nuevo cupo de atención disponible', example: 'uuid-nuevo-slot' })
  @IsString()
  @IsNotEmpty()
  newSlotId: string;
}

export class CancelAppointmentDto {
  @ApiProperty({ description: 'Motivo de la cancelación del turno', example: 'Imposibilidad de acudir por motivos laborales' })
  @IsString()
  @IsNotEmpty()
  reason: string;
}

