import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuditService } from './audit.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RoleType } from '@prisma/client';

@ApiTags('Auditoría y Trazabilidad (RF09)')
@Controller('audit')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get('logs')
  @Roles(RoleType.ADMIN, RoleType.SUPPORT)
  @ApiOperation({
    summary: 'Consultar logs de auditoría sin datos sensibles ni contraseñas (Solo Admin y Soporte)',
  })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'skip', required: false, type: Number })
  async getAuditLogs(
    @Query('limit') limit = 50,
    @Query('skip') skip = 0,
  ) {
    return this.auditService.findAll(Number(limit), Number(skip));
  }
}

