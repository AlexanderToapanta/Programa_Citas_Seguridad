import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateAuthorizationDto } from './dto/representative.dto';
import { AuthorizationStatus } from '@prisma/client';

@Injectable()
export class RepresentativesService {
  constructor(private prisma: PrismaService) {}

  /**
   * Conceder autorización formal a un familiar para gestionar turnos médicos (RF04)
   * Sin depender únicamente de cédula y fecha de nacimiento
   */
  async createAuthorization(principalUserId: string, dto: CreateAuthorizationDto) {
    const representative = await this.prisma.user.findUnique({
      where: { idCard: dto.representativeIdCard },
    });

    if (!representative) {
      throw new NotFoundException('El familiar indicado no se encuentra registrado en el sistema');
    }

    if (representative.id === principalUserId) {
      throw new BadRequestException('No puede otorgarse una autorización familiar a usted mismo');
    }

    const validUntilDate = new Date(dto.validUntil);
    if (validUntilDate <= new Date()) {
      throw new BadRequestException('La fecha de vigencia debe ser posterior a la fecha actual');
    }

    return this.prisma.familyAuthorization.upsert({
      where: {
        principalUserId_representativeUserId: {
          principalUserId,
          representativeUserId: representative.id,
        },
      },
      update: {
        relationship: dto.relationship,
        verificationMethod: dto.verificationMethod,
        verificationProof: dto.verificationProof,
        status: AuthorizationStatus.ACTIVE,
        validUntil: validUntilDate,
      },
      create: {
        principalUserId,
        representativeUserId: representative.id,
        relationship: dto.relationship,
        verificationMethod: dto.verificationMethod,
        verificationProof: dto.verificationProof,
        status: AuthorizationStatus.ACTIVE,
        validUntil: validUntilDate,
      },
      include: {
        representative: {
          select: {
            idCard: true,
            fullName: true,
            email: true,
          },
        },
      },
    });
  }

  /**
   * Consultar autorizaciones emitidas por el usuario
   */
  async getMyGivenAuthorizations(userId: string) {
    return this.prisma.familyAuthorization.findMany({
      where: { principalUserId: userId },
      include: {
        representative: {
          select: { idCard: true, fullName: true, phoneNumber: true },
        },
      },
    });
  }

  /**
   * Consultar personas que me han autorizado a gestionar sus citas
   */
  async getMyReceivedAuthorizations(userId: string) {
    return this.prisma.familyAuthorization.findMany({
      where: {
        representativeUserId: userId,
        status: AuthorizationStatus.ACTIVE,
        validUntil: { gte: new Date() },
      },
      include: {
        principal: {
          select: { idCard: true, fullName: true, phoneNumber: true },
        },
      },
    });
  }

  /**
   * Revocar una autorización familiar activa
   */
  async revokeAuthorization(principalUserId: string, authorizationId: string) {
    const auth = await this.prisma.familyAuthorization.findUnique({
      where: { id: authorizationId },
    });

    if (!auth || auth.principalUserId !== principalUserId) {
      throw new NotFoundException('Autorización no encontrada');
    }

    return this.prisma.familyAuthorization.update({
      where: { id: authorizationId },
      data: { status: AuthorizationStatus.REVOKED },
    });
  }
}

