import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  // 1. Cabeceras de seguridad HTTP con Helmet (R06)
  app.use(helmet());

  // 2. Configuración restrictiva de CORS (R06)
  const allowedOrigins = (process.env.CORS_ORIGIN || 'http://localhost:3000,http://localhost:5173')
    .split(',')
    .map((origin) => origin.trim());

  app.enableCors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Bloqueado por política CORS de seguridad'));
      }
    },
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  // 3. Validación estricta global y sanitización con class-validator (R05, R02)
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // Elimina propiedades extrañas no definidas en DTO
      forbidNonWhitelisted: true, // Rechaza solicitudes con campos sospechosos
      transform: true,
    }),
  );

  // 4. Documentación interactiva OpenAPI / Swagger (RF01 - RF11)
  const config = new DocumentBuilder()
    .setTitle('IESS - Sistema de Turnos Médicos (Etapa 1: Backend Seguro)')
    .setDescription(
      'Documentación técnica y especificación OpenAPI de los endpoints del sistema universitario de turnos médicos del IESS. ' +
        'Incluye autenticación Argon2id, minimización LOPDP, reglas de inasistencias y citas activas, control BOLA/IDOR y auditoría sanitizada.',
    )
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document, {
    customSiteTitle: 'Swagger UI - Sistema de Turnos IESS',
  });

  const port = process.env.PORT || 3000;
  await app.listen(port);
  logger.log(`================================================================`);
  logger.log(`✓ Servidor IESS Turnos ejecutándose en: http://localhost:${port}`);
  logger.log(`✓ Documentación Swagger disponible en: http://localhost:${port}/api/docs`);
  logger.log(`✓ Health check disponible en: http://localhost:${port}/health`);
  logger.log(`================================================================`);
}

bootstrap();

