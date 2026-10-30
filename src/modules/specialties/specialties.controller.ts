import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles, Public } from '../../common/decorators/roles.decorator';
import { RoleType } from '@prisma/client';
import { IsString, IsNotEmpty, IsBoolean } from 'class-validator';

export class CreateSpecialtyDto {
  @IsString()
  @IsNotEmpty()
  code: string;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  description: string;

  @IsBoolean()
  requiresReferral: boolean;
}

@ApiTags('Especialidades Médicas (RF01)')
@Controller('specialties')
export class SpecialtiesController {
  constructor(private prisma: PrismaService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'Consultar especialidades médicas disponibles con indicación de necesidad de derivación' })
  async getSpecialties() {
    return this.prisma.specialty.findMany({
      orderBy: { name: 'asc' },
    });
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(RoleType.ADMIN)
  @ApiBearerAuth()
  @Post()
  @ApiOperation({ summary: 'Crear nueva especialidad médica (Exclusivo Administrador)' })
  async createSpecialty(@Body() dto: CreateSpecialtyDto) {
    return this.prisma.specialty.create({
      data: dto,
    });
  }
}

