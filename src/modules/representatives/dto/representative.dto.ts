import { IsString, IsNotEmpty, IsDateString, IsIn } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateAuthorizationDto {
  @ApiProperty({ description: 'Cédula del familiar que será autorizado a gestionar turnos', example: '1715897451' })
  @IsString()
  @IsNotEmpty()
  representativeIdCard: string;

  @ApiProperty({ description: 'Parentesco o vínculo', example: 'HIJO', enum: ['HIJO', 'PADRE', 'MADRE', 'CONYUGE', 'TUTOR_LEGAL'] })
  @IsString()
  @IsIn(['HIJO', 'PADRE', 'MADRE', 'CONYUGE', 'TUTOR_LEGAL'])
  relationship: string;

  @ApiProperty({ description: 'Método de validación', example: 'OTP_CONTACTO', enum: ['CODIGO_DACTILAR', 'OTP_CONTACTO', 'TUTORIA_ASISTIDA'] })
  @IsString()
  @IsIn(['CODIGO_DACTILAR', 'OTP_CONTACTO', 'TUTORIA_ASISTIDA'])
  verificationMethod: string;

  @ApiProperty({ description: 'Código de verificación / prueba de mandato', example: '892341' })
  @IsString()
  @IsNotEmpty()
  verificationProof: string;

  @ApiProperty({ description: 'Fecha de vigencia (YYYY-MM-DD)', example: '2027-12-31' })
  @IsDateString()
  validUntil: string;
}

