import {
  IsString,
  IsEmail,
  IsNotEmpty,
  Matches,
  IsDateString,
  MinLength,
  MaxLength,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RegisterUserDto {
  @ApiProperty({ description: 'Cédula de identidad ecuatoriana válida (10 dígitos)', example: '1715897451' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^\d{10}$/, { message: 'La cédula debe contener exactamente 10 dígitos numéricos' })
  idCard: string;

  @ApiProperty({ description: 'Nombres y apellidos completos', example: 'Pedro Antonio Pérez' })
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  @MaxLength(120)
  fullName: string;

  @ApiProperty({ description: 'Fecha de nacimiento (ISO 8601)', example: '1990-05-15' })
  @IsDateString({}, { message: 'La fecha de nacimiento debe tener formato YYYY-MM-DD' })
  birthDate: string;

  @ApiProperty({ description: 'Correo electrónico de contacto para notificaciones', example: 'pedro.perez@example.com' })
  @IsEmail({}, { message: 'El correo electrónico no es válido' })
  email: string;

  @ApiProperty({ description: 'Número celular ecuatoriano (10 dígitos comenzando con 09)', example: '0981234567' })
  @IsString()
  @Matches(/^09\d{8}$/, { message: 'El número telefónico debe ser celular ecuatoriano válido de 10 dígitos (09...)' })
  phoneNumber: string;
}

export class LoginDto {
  @ApiProperty({ description: 'Cédula de identidad como nombre de usuario', example: '1715897451' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^\d{10}$/, { message: 'La cédula debe contener exactamente 10 dígitos numéricos' })
  idCard: string;

  @ApiProperty({ description: 'Contraseña o credencial temporal', example: 'Iess2026!Temporal' })
  @IsString()
  @IsNotEmpty()
  password: string;
}

export class ChangePasswordDto {
  @ApiProperty({ description: 'Contraseña actual o credencial temporal', example: 'Iess2026!Temporal' })
  @IsString()
  @IsNotEmpty()
  currentPassword: string;

  @ApiProperty({
    description: 'Nueva contraseña personal segura (mínimo 8 caracteres, mayúscula, minúscula, número y símbolo)',
    example: 'MiNuevaClaveSegura2026!',
  })
  @IsString()
  @MinLength(8, { message: 'La nueva contraseña debe tener al menos 8 caracteres' })
  @Matches(/((?=.*\d)|(?=.*\W+))(?![.\n])(?=.*[A-Z])(?=.*[a-z]).*$/, {
    message: 'La contraseña debe contener al menos una mayúscula, una minúscula y un número o símbolo especial',
  })
  newPassword: string;
}

export class RequestPasswordResetDto {
  @ApiProperty({ description: 'Cédula de identidad registrada', example: '1715897451' })
  @IsString()
  @Matches(/^\d{10}$/)
  idCard: string;
}

