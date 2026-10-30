import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { SpecialtiesModule } from './modules/specialties/specialties.module';
import { FacilitiesModule } from './modules/facilities/facilities.module';
import { AvailabilityModule } from './modules/availability/availability.module';
import { AppointmentsModule } from './modules/appointments/appointments.module';
import { RepresentativesModule } from './modules/representatives/representatives.module';
import { AuditModule } from './modules/audit/audit.module';
import { IntegrationsModule } from './modules/integrations/integrations.module';
import { HealthController } from './modules/health.controller';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { AuditInterceptor } from './common/interceptors/audit.interceptor';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    // R02 / R03: Rate Limiting global y específico para mitigar DoS y fuerza bruta
    ThrottlerModule.forRoot([
      {
        name: 'short',
        ttl: 1000, // 1 segundo
        limit: 10, // Máximo 10 req/segundo por IP
      },
      {
        name: 'medium',
        ttl: 60000, // 1 minuto
        limit: 100, // Máximo 100 req/minuto
      },
      {
        name: 'auth',
        ttl: 300000, // 5 minutos
        limit: 30, // Máximo 30 intentos globales en auth
      },
    ]),
    PrismaModule,
    IntegrationsModule,
    AuditModule,
    AuthModule,
    UsersModule,
    SpecialtiesModule,
    FacilitiesModule,
    AvailabilityModule,
    AppointmentsModule,
    RepresentativesModule,
  ],
  controllers: [HealthController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_FILTER,
      useClass: GlobalExceptionFilter,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: AuditInterceptor,
    },
  ],
})
export class AppModule {}

