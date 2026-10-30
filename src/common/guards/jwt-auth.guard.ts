import { Injectable, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from '../../common/decorators/roles.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    return super.canActivate(context);
  }

  handleRequest(err: any, user: any, info: any, context: ExecutionContext) {
    if (err || !user) {
      throw err || new UnauthorizedException('Token de autenticación inválido o ausente');
    }

    // Si el usuario tiene la bandera mustChangePassword activa y no está en la ruta de cambio de contraseña
    const request = context.switchToHttp().getRequest();
    const isPasswordChangePath = request.url.includes('/auth/change-password');

    if (user.mustChangePassword && !isPasswordChangePath) {
      throw new UnauthorizedException(
        'Primer acceso detectado: Debe cambiar obligatoriamente su contraseña temporal antes de continuar.',
      );
    }

    return user;
  }
}

