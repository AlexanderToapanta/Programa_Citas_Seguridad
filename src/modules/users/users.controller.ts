import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RoleType } from '@prisma/client';

@ApiTags('Usuarios y Perfil (RF02, RF06)')
@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class UsersController {
  constructor(private prisma: PrismaService) {}

  @Get('me')
  @ApiOperation({ summary: 'Obtener información del perfil autenticado con minimización de datos' })
  async getProfile(@CurrentUser('id') userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        idCard: true,
        fullName: true,
        birthDate: true,
        email: true,
        phoneNumber: true,
        mustChangePassword: true,
        createdAt: true,
        roles: {
          select: {
            role: {
              select: { name: true, description: true },
            },
          },
        },
      },
    });
    return {
      ...user,
      roles: user.roles.map((r) => r.role.name),
    };
  }

  @Get()
  @Roles(RoleType.ADMIN, RoleType.SUPPORT)
  @ApiOperation({ summary: 'Listar usuarios del sistema (Acceso exclusivo Administrador y Soporte)' })
  async listUsers() {
    const users = await this.prisma.user.findMany({
      take: 50,
      select: {
        id: true,
        idCard: true,
        fullName: true,
        email: true,
        phoneNumber: true,
        status: true,
        createdAt: true,
        roles: {
          select: { role: { select: { name: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return users.map((u) => ({ ...u, roles: u.roles.map((r) => r.role.name) }));
  }
}

