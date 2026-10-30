import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles, Public } from '../../common/decorators/roles.decorator';
import { RoleType } from '@prisma/client';
import { IsString, IsNotEmpty } from 'class-validator';

export class CreateFacilityDto {
  @IsString()
  @IsNotEmpty()
  code: string;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  address: string;

  @IsString()
  @IsNotEmpty()
  city: string;

  @IsString()
  @IsNotEmpty()
  phone: string;
}

@ApiTags('Establecimientos de Salud (RF01)')
@Controller('facilities')
export class FacilitiesController {
  constructor(private prisma: PrismaService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'Consultar red de centros y hospitales del IESS' })
  async getFacilities() {
    return this.prisma.facility.findMany({
      orderBy: { name: 'asc' },
    });
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(RoleType.ADMIN)
  @ApiBearerAuth()
  @Post()
  @ApiOperation({ summary: 'Registrar nuevo establecimiento médico (Exclusivo Administrador)' })
  async createFacility(@Body() dto: CreateFacilityDto) {
    return this.prisma.facility.create({
      data: dto,
    });
  }
}

