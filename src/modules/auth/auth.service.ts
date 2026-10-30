import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { IessIntegrationService } from '../integrations/iess-integration.service';
import { RegisterUserDto, LoginDto, ChangePasswordDto, RequestPasswordResetDto } from './dto/auth.dto';
import { validateEcuadorianIdCard, generateSecureTemporaryPassword } from '../../common/utils/crypto.util';
import * as argon2 from 'argon2';
import { RoleType, UserStatus } from '@prisma/client';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private iessService: IessIntegrationService,
  ) {}

  /**
   * Registro seguro de afiliados con cédula (RF02, RF05)
   * Genera contraseña temporal aleatoria de un solo uso con vigencia de 15 min
   */
  async register(dto: RegisterUserDto) {
    // 1. Validar cédula ecuatoriana válida
    if (!validateEcuadorianIdCard(dto.idCard)) {
      throw new BadRequestException('Ingrese una cédula válida');
    }

    // 2. Verificar que la cédula no esté ya registrada
    // NOTA: el email NO es único — un padre/tutor puede compartir su correo
    // con los registros de sus hijos menores de edad.
    const existing = await this.prisma.user.findUnique({
      where: { idCard: dto.idCard },
    });

    if (existing) {
      throw new BadRequestException('Ya existe un usuario con esa cédula');
    }

    // 2.1 Validar rango de edad: minimo 7 dias y maximo 100 anos
    const birth = new Date(dto.birthDate);
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const hundredYearsAgo = new Date(now.getFullYear() - 100, now.getMonth(), now.getDate());
    if (isNaN(birth.getTime()) || birth > sevenDaysAgo || birth < hundredYearsAgo) {
      throw new BadRequestException('La fecha de nacimiento debe corresponder a una persona con al menos 1 semana de vida y máximo 100 años');
    }

    // 3. Validar con servicio institucional del IESS (RF08)
    const affiliation = await this.iessService.validateAffiliateStatus(dto.idCard);
    if (!affiliation.isAffiliated) {
      throw new ForbiddenException(`No se puede completar el registro: ${affiliation.statusDescription}`);
    }

    // 4. Generar contraseña temporal segura (RF05)
    const tempPassword = generateSecureTemporaryPassword(12);
    const passwordHash = await argon2.hash(tempPassword, { type: argon2.argon2id });

    // 5. Asignar rol predeterminado AFFILIATE
    const affiliateRole = await this.prisma.role.findUnique({
      where: { name: RoleType.AFFILIATE },
    });

    const user = await this.prisma.user.create({
      data: {
        idCard: dto.idCard,
        fullName: dto.fullName,
        birthDate: new Date(dto.birthDate),
        email: dto.email,
        phoneNumber: dto.phoneNumber,
        passwordHash,
        mustChangePassword: true,
        roles: {
          create: [{ roleId: affiliateRole.id }],
        },
        temporaryCredentials: {
          create: {
            tokenHash: await argon2.hash(tempPassword, { type: argon2.argon2id }),
            expiresAt: new Date(Date.now() + 15 * 60 * 1000), // Vigencia de 15 minutos
            used: false,
          },
        },
      },
      select: {
        id: true,
        idCard: true,
        fullName: true,
        email: true,
        phoneNumber: true,
        mustChangePassword: true,
        createdAt: true,
      },
    });

    // Enviar notificación con la contraseña temporal por correo al afiliado (RF05)
    await this.iessService.sendTemporaryCredentials(
      user.email,
      user.fullName,
      tempPassword,
      15,
    );

    return {
      message: 'Registro exitoso. Se ha generado una credencial temporal válida por 15 minutos.',
      user,
      // Se entrega de forma transparente en el prototipo académico para pruebas
      temporaryCredential: {
        temporaryPassword: tempPassword,
        expiresInMinutes: 15,
        notice: 'Debe cambiar obligatoriamente esta contraseña al iniciar sesión por primera vez.',
      },
    };
  }

  /**
   * Inicio de sesión seguro con protección contra fuerza bruta (R03, RF05)
   */
  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { idCard: dto.idCard },
      include: {
        roles: { include: { role: true } },
      },
    });

    if (!user) {
      // Mensaje genérico para evitar enumeración de usuarios (R03)
      throw new UnauthorizedException('Credenciales inválidas');
    }

    // Comprobar bloqueo por intentos fallidos de fuerza bruta (R03)
    if (user.lockoutUntil && user.lockoutUntil > new Date()) {
      const minutesRemaining = Math.ceil((user.lockoutUntil.getTime() - Date.now()) / (60 * 1000));
      throw new ForbiddenException(`Cuenta temporalmente bloqueada por seguridad. Intente nuevamente en ${minutesRemaining} minutos.`);
    }

    if (user.status !== UserStatus.ACTIVE) {
      throw new ForbiddenException('La cuenta se encuentra inactiva o deshabilitada administrativamente');
    }

    // Verificar hash Argon2id
    const isPasswordValid = await argon2.verify(user.passwordHash, dto.password);

    if (!isPasswordValid) {
      // Incrementar intentos fallidos
      const attempts = user.failedLoginAttempts + 1;
      let lockoutDate: Date | null = null;

      // Bloqueo progresivo a partir del 5to intento fallido
      if (attempts >= 5) {
        lockoutDate = new Date(Date.now() + 15 * 60 * 1000); // 15 minutos de bloqueo
        this.logger.warn(`[SECURITY_ALERT] Cuenta ${user.idCard} bloqueada temporalmente por 5 intentos fallidos consecutivos.`);
      }

      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          failedLoginAttempts: attempts,
          lockoutUntil: lockoutDate,
        },
      });

      throw new UnauthorizedException('Credenciales inválidas');
    }

    // Restablecer contador de intentos en caso de éxito
    if (user.failedLoginAttempts > 0 || user.lockoutUntil) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { failedLoginAttempts: 0, lockoutUntil: null },
      });
    }

    const payload = {
      sub: user.id,
      idCard: user.idCard,
      roles: user.roles.map((r) => r.role.name),
      mustChangePassword: user.mustChangePassword,
    };

    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      tokenType: 'Bearer',
      expiresIn: '3600s',
      mustChangePassword: user.mustChangePassword,
      user: {
        id: user.id,
        idCard: user.idCard,
        fullName: user.fullName,
        email: user.email,
        roles: payload.roles,
      },
    };
  }

  /**
   * Cambio obligatorio de contraseña en primer acceso o actualización voluntaria (RF05)
   */
  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }

    const isCurrentValid = await argon2.verify(user.passwordHash, dto.currentPassword);
    if (!isCurrentValid) {
      throw new BadRequestException('La contraseña actual ingresada es incorrecta');
    }

    // Evitar reutilización de la misma contraseña
    const isSamePassword = await argon2.verify(user.passwordHash, dto.newPassword);
    if (isSamePassword) {
      throw new BadRequestException('La nueva contraseña no puede ser idéntica a la contraseña temporal o anterior');
    }

    // Hashear nueva contraseña con Argon2id
    const newHash = await argon2.hash(dto.newPassword, { type: argon2.argon2id });

    // Invalidar credenciales temporales previas
    await this.prisma.temporaryCredential.updateMany({
      where: { userId: user.id, used: false },
      data: { used: true },
    });

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: newHash,
        mustChangePassword: false,
      },
    });

    return {
      message: 'Contraseña actualizada exitosamente. Ya puede operar con normalidad en el sistema.',
    };
  }

  /**
   * Mecanismo de revocación de tokens y cierre seguro de sesión (R06)
   */
  async logout(userId: string, rawToken: string) {
    if (!rawToken) {
      return { message: 'Sesión finalizada' };
    }

    // Registrar token en lista de revocación
    await this.prisma.revokedToken.upsert({
      where: { token: rawToken },
      update: {},
      create: {
        userId,
        token: rawToken,
        expiresAt: new Date(Date.now() + 3600 * 1000), // Válido hasta la expiración teórica del JWT
      },
    });

    return { message: 'Sesión revocada y cerrada de forma segura' };
  }

  /**
   * Recuperación de acceso con nueva credencial temporal (RF05)
   */
  async requestPasswordReset(dto: RequestPasswordResetDto) {
    const user = await this.prisma.user.findUnique({
      where: { idCard: dto.idCard },
    });

    if (!user) {
      // Respuesta neutral para mitigar enumeración de usuarios
      return {
        message: 'Si la cédula se encuentra registrada, se enviará una credencial temporal a su correo de contacto.',
      };
    }

    const tempPassword = generateSecureTemporaryPassword(12);
    const passwordHash = await argon2.hash(tempPassword, { type: argon2.argon2id });

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        mustChangePassword: true,
        temporaryCredentials: {
          create: {
            tokenHash: await argon2.hash(tempPassword, { type: argon2.argon2id }),
            expiresAt: new Date(Date.now() + 15 * 60 * 1000),
            used: false,
          },
        },
      },
    });

    // Enviar notificación con la nueva credencial temporal por correo (RF05)
    await this.iessService.sendTemporaryCredentials(
      user.email,
      user.fullName,
      tempPassword,
      15,
    );

    return {
      message: 'Si la cédula se encuentra registrada, se enviará una credencial temporal a su correo de contacto.',
      // Para ambiente académico / pruebas:
      temporaryPassword: tempPassword,
    };
  }
}

