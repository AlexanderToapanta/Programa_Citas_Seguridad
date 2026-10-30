import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../../prisma/prisma.service';

export interface JwtPayload {
  sub: string;
  idCard: string;
  roles: string[];
  mustChangePassword: boolean;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private configService: ConfigService,
    private prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET') || 'super_secret_jwt_key_at_least_32_chars_long_2026',
      passReqToCallback: true,
    });
  }

  async validate(req: any, payload: JwtPayload) {
    const rawToken = ExtractJwt.fromAuthHeaderAsBearerToken()(req);

    // Verificar si el token se encuentra en la lista de revocación (R06 / Logout)
    if (rawToken) {
      const isRevoked = await this.prisma.revokedToken.findUnique({
        where: { token: rawToken },
      });
      if (isRevoked) {
        throw new UnauthorizedException('La sesión ha sido revocada o cerrada. Inicie sesión nuevamente.');
      }
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: {
        roles: {
          include: { role: true },
        },
      },
    });

    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Usuario no válido o bloqueado.');
    }

    return {
      id: user.id,
      idCard: user.idCard,
      fullName: user.fullName,
      email: user.email,
      roles: user.roles.map((r) => r.role.name),
      mustChangePassword: user.mustChangePassword,
      rawToken,
    };
  }
}

