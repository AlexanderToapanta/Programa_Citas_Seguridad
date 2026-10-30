import { Controller, Post, Get, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { RepresentativesService } from './representatives.service';
import { CreateAuthorizationDto } from './dto/representative.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Familiares y Representación Autorizada (RF04)')
@Controller('representatives')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class RepresentativesController {
  constructor(private readonly representativesService: RepresentativesService) {}

  @Post()
  @ApiOperation({ summary: 'Otorgar autorización a un familiar mediante mecanismo verificable (OTP / Huella)' })
  @ApiResponse({ status: 201, description: 'Autorización creada/actualizada exitosamente' })
  async createAuthorization(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateAuthorizationDto,
  ) {
    return this.representativesService.createAuthorization(userId, dto);
  }

  @Get('my-authorizations')
  @ApiOperation({ summary: 'Listar familiares que he autorizado a gestionar mis citas' })
  async getMyGivenAuthorizations(@CurrentUser('id') userId: string) {
    return this.representativesService.getMyGivenAuthorizations(userId);
  }

  @Get('delegated-to-me')
  @ApiOperation({ summary: 'Listar afiliados que me han delegado la gestión de sus turnos' })
  async getMyReceivedAuthorizations(@CurrentUser('id') userId: string) {
    return this.representativesService.getMyReceivedAuthorizations(userId);
  }

  @Patch(':id/revoke')
  @ApiOperation({ summary: 'Revocar inmediatamente una autorización familiar previa' })
  async revokeAuthorization(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
  ) {
    return this.representativesService.revokeAuthorization(userId, id);
  }
}

