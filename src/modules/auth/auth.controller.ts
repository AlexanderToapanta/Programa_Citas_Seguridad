import { Controller, Post, Body, HttpCode, HttpStatus, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { RegisterUserDto, LoginDto, ChangePasswordDto, RequestPasswordResetDto } from './dto/auth.dto';
import { Public } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Autenticación y Seguridad (RF02, RF05)')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('register')
  @ApiOperation({ summary: 'Registro de nuevo afiliado con cédula y credencial temporal de 15 minutos' })
  @ApiResponse({ status: 201, description: 'Usuario registrado con éxito' })
  @ApiResponse({ status: 400, description: 'Cédula inválida o datos incorrectos' })
  async register(@Body() dto: RegisterUserDto) {
    return this.authService.register(dto);
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 300000 } }) // R03 / Fuerza bruta: Máximo 5 intentos por IP en 5 minutos
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Inicio de sesión seguro con cédula y contraseña / Argon2id' })
  @ApiResponse({ status: 200, description: 'Sesión iniciada; entrega de token JWT' })
  @ApiResponse({ status: 401, description: 'Credenciales inválidas' })
  @ApiResponse({ status: 403, description: 'Cuenta temporalmente bloqueada por intentos fallidos' })
  @ApiResponse({ status: 429, description: 'Límite de intentos de autenticación excedido (R03)' })
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Post('change-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cambio obligatorio de contraseña en primer acceso o actualización voluntaria' })
  @ApiResponse({ status: 200, description: 'Contraseña actualizada y credenciales temporales invalidadas' })
  async changePassword(
    @CurrentUser('id') userId: string,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.authService.changePassword(userId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cierre de sesión y revocación del token de acceso' })
  async logout(
    @CurrentUser('id') userId: string,
    @CurrentUser('rawToken') rawToken: string,
  ) {
    return this.authService.logout(userId, rawToken);
  }

  @Public()
  @Post('request-reset')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Solicitud de reposición de credencial temporal' })
  async requestReset(@Body() dto: RequestPasswordResetDto) {
    return this.authService.requestPasswordReset(dto);
  }
}

