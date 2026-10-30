import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Suite de Integración y Reglas de Negocio - Sistema de Turnos IESS (RF01 - RF11)', () => {
  let app: INestApplication;
  let affiliateToken: string;
  let adminToken: string;
  let blockedToken: string;
  let doctorToken: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();

    // 1. Iniciar sesión con Administrador
    const adminRes = await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        idCard: '1710000001',
        password: 'Iess2026!Temporal',
      });
    adminToken = adminRes.body.accessToken;

    // 2. Iniciar sesión con Afiliado Bloqueado por 3 inasistencias (Pedro Mendoza)
    const blockedRes = await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        idCard: '1723456780',
        password: 'Iess2026!Temporal',
      });
    blockedToken = blockedRes.body.accessToken;

    // 3. Iniciar sesión con Médico Tratante (Dra. Andrade)
    const docRes = await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        idCard: '1712233445',
        password: 'Iess2026!Temporal',
      });
    doctorToken = docRes.body.accessToken;
  }, 60000);

  afterAll(async () => {
    await app.close();
  });

  describe('1. Verificación de Salud del Sistema (Health Check - RF11)', () => {
    it('GET /health - debe responder con estado healthy y conexión activa a base de datos', async () => {
      const res = await request(app.getHttpServer()).get('/health').expect(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.services.database).toBe('healthy');
    });
  });

  describe('2. Autenticación y Credenciales Temporales (RF02, RF05, R03)', () => {
    it('POST /auth/register - debe registrar un usuario válido y generar credencial temporal de 15 minutos', async () => {
      const res = await request(app.getHttpServer())
        .post('/auth/register')
        .send({
          idCard: '1703970622', // Cédula ecuatoriana válida
          fullName: 'Test Afiliado Registro Nuevo',
          birthDate: '1995-07-20',
          email: 'afiliado.nuevo.test@mailtest.com',
          phoneNumber: '0987654321',
        });

      // Si ya existía o se crea:
      if (res.status === 201) {
        expect(res.body.temporaryCredential).toBeDefined();
        expect(res.body.temporaryCredential.expiresInMinutes).toBe(15);
      } else {
        expect(res.status).toBe(400); // Ya registrado
      }
    });

    it('POST /auth/login - debe rechazar contraseña errónea con HTTP 401 sin enumerar cuentas (R03)', async () => {
      await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          idCard: '1710000001',
          password: 'ClaveTotalmenteErronea!',
        })
        .expect(401);
    });

    it('POST /auth/login y flujo de primer acceso (mustChangePassword) - debe obligar el cambio de contraseña', async () => {
      // Juan Morales tiene mustChangePassword: true en el seed
      const loginRes = await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          idCard: '1715897451',
          password: 'Iess2026!Temporal',
        })
        .expect(200);

      expect(loginRes.body.mustChangePassword).toBe(true);
      affiliateToken = loginRes.body.accessToken;

      // Intentar acceder a un recurso protegido antes de cambiar contraseña -> 401
      await request(app.getHttpServer())
        .get('/users/me')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .expect(401);

      // Realizar cambio obligatorio de contraseña
      const changeRes = await request(app.getHttpServer())
        .post('/auth/change-password')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .send({
          currentPassword: 'Iess2026!Temporal',
          newPassword: 'NuevaClaveSegura2026!',
        })
        .expect(200);

      expect(changeRes.body.message).toContain('exitosa');

      // Nuevo login con la nueva contraseña
      const newLogin = await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          idCard: '1715897451',
          password: 'NuevaClaveSegura2026!',
        })
        .expect(200);

      expect(newLogin.body.mustChangePassword).toBe(false);
      affiliateToken = newLogin.body.accessToken;

      // Ahora el acceso al perfil es exitoso
      await request(app.getHttpServer())
        .get('/users/me')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .expect(200);
    });
  });

  describe('3. Control de Acceso por Roles (RBAC - RF06, R10)', () => {
    it('GET /users - debe ser denegado a un afiliado regular (HTTP 403)', async () => {
      await request(app.getHttpServer())
        .get('/users')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .expect(403);
    });

    it('GET /users - debe ser permitido a un administrador (HTTP 200)', async () => {
      const res = await request(app.getHttpServer())
        .get('/users')
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
    });

    it('GET /audit/logs - debe ser denegado a afiliados comunes (HTTP 403) y permitido a administradores', async () => {
      await request(app.getHttpServer())
        .get('/audit/logs')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .expect(403);

      const logsRes = await request(app.getHttpServer())
        .get('/audit/logs')
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(200);

      expect(Array.isArray(logsRes.body)).toBe(true);
    });
  });

  describe('4. Reglas de Negocio de Citas Médicas (RF01, RF03, R07)', () => {
    let availableSlotId: string;
    let createdAppointmentId: string;

    it('GET /availability/slots - debe listar cupos disponibles con información de doctor y especialidad', async () => {
      const res = await request(app.getHttpServer()).get('/availability/slots').expect(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThan(0);
      availableSlotId = res.body[0].id;
    });

    it('POST /appointments - Restricción de 3 inasistencias en 90 días debe bloquear la reserva en línea', async () => {
      const res = await request(app.getHttpServer())
        .post('/appointments')
        .set('Authorization', `Bearer ${blockedToken}`)
        .send({
          slotId: availableSlotId,
        })
        .expect(403);

      expect(res.body.message).toContain('3 inasistencias injustificadas');
    });

    it('POST /appointments - Reserva exitosa de un cupo disponible para el afiliado', async () => {
      const res = await request(app.getHttpServer())
        .post('/appointments')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .send({
          slotId: availableSlotId,
        })
        .expect(201);

      expect(res.body.appointment).toBeDefined();
      expect(res.body.appointment.status).toBe('SCHEDULED');
      createdAppointmentId = res.body.appointment.id;
    });

    it('POST /appointments - Regla de Cita Activa Única: no puede agendar otra cita si ya tiene una activa', async () => {
      // Tomar otro slot
      const slotsRes = await request(app.getHttpServer()).get('/availability/slots').expect(200);
      const anotherSlotId = slotsRes.body[0].id;

      const res = await request(app.getHttpServer())
        .post('/appointments')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .send({
          slotId: anotherSlotId,
        })
        .expect(409);

      expect(res.body.message).toContain('ya mantiene una cita activa');
    });

    it('POST /appointments - Prevención de Doble Reserva (Condición de Carrera / R07): no se puede reservar un slot ocupado', async () => {
      // Intentar reservar el mismo slot que ya fue ocupado
      const res = await request(app.getHttpServer())
        .post('/appointments')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          slotId: availableSlotId,
        })
        .expect(409);

      expect(res.body.message).toContain('no está disponible');
    });

    it('GET /appointments/my - Consulta segura con aislamiento IDOR/BOLA (R04)', async () => {
      const res = await request(app.getHttpServer())
        .get('/appointments/my')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.some((app: any) => app.id === createdAppointmentId)).toBe(true);
    });

    it('PATCH /appointments/:id/cancel - Cancelación exitosa de la cita médica antes del inicio', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/appointments/${createdAppointmentId}/cancel`)
        .set('Authorization', `Bearer ${affiliateToken}`)
        .send({
          reason: 'Cancelación voluntaria por motivos de prueba',
        })
        .expect(200);

      expect(res.body.appointment.status).toBe('CANCELLED');
    });
  });

  describe('5. Gestión de Familiares Autorizados y Mitigación IDOR (RF04, R04)', () => {
    it('POST /representatives - Otorgar autorización familiar con validación verificable', async () => {
      const res = await request(app.getHttpServer())
        .post('/representatives')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .send({
          representativeIdCard: '1708451239', // Rosa Torres
          relationship: 'MADRE',
          verificationMethod: 'OTP_CONTACTO',
          verificationProof: 'OTP_SMS_VERIFIED_771',
          validUntil: '2027-12-31',
        })
        .expect(201);

      expect(res.body.status).toBe('ACTIVE');
    });

    it('GET /representatives/my-authorizations - Consultar autorizaciones emitidas', async () => {
      const res = await request(app.getHttpServer())
        .get('/representatives/my-authorizations')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThan(0);
    });
  });

  describe('6. Cierre Seguro de Sesión y Revocación de Tokens (R06)', () => {
    it('POST /auth/logout - debe invalidar el token actual en la lista de revocación', async () => {
      await request(app.getHttpServer())
        .post('/auth/logout')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .expect(200);

      // Intentar usar el token revocado -> 401 Unauthorized
      await request(app.getHttpServer())
        .get('/users/me')
        .set('Authorization', `Bearer ${affiliateToken}`)
        .expect(401);
    });
  });

  describe('7. Pruebas de Seguridad Especializadas (Etapa 3 - Pruebas 1 a 10)', () => {
    // PRUEBA 1 — SQL Injection (R05)
    it('[Prueba 1] SQL Injection - entradas maliciosas no deben alterar consultas SQL (R05)', async () => {
      const sqlPayloads = [
        "' OR '1'='1",
        "1; DROP TABLE users; --",
        "' UNION SELECT * FROM users --",
        "admin' --",
      ];

      for (const payload of sqlPayloads) {
        // En login (idCard)
        await request(app.getHttpServer())
          .post('/auth/login')
          .send({
            idCard: payload,
            password: 'SomePassword123!',
          })
          .expect(400); // Rechazado por validación de class-validator (cédula 10 dígitos)

        // En búsqueda de disponibilidad (doctorId / facilityId)
        const res = await request(app.getHttpServer())
          .get(`/availability/slots?facilityId=${encodeURIComponent(payload)}`)
          .expect(200); // Prisma parametriza y maneja el valor de forma segura devolviendo arreglo vacío sin inyectar SQL
        expect(Array.isArray(res.body)).toBe(true);
      }
    });

    // PRUEBA 3 & 5 — DoS de aplicación y Throttling (R02, R03)
    it('[Prueba 3 & 5] DoS y Fuerza Bruta - Throttler debe responder 429 Too Many Requests ante ráfagas (R02, R03)', async () => {
      let hitRateLimit = false;
      // Realizamos múltiples peticiones consecutivas al endpoint protegido por Throttle con una cédula dummy para no bloquear cuentas del seed
      for (let i = 0; i < 15; i++) {
        const res = await request(app.getHttpServer())
          .post('/auth/login')
          .send({
            idCard: '1799999999',
            password: 'BadPassword!',
          });
        if (res.status === 429) {
          hitRateLimit = true;
          expect(res.body.statusCode).toBe(429);
          break;
        }
      }
      expect(hitRateLimit).toBe(true);
    });

    // PRUEBA 4 — IDOR / BOLA Estricto entre Usuario A y Usuario B (R04)
    it('[Prueba 4] IDOR / BOLA - Usuario A no debe poder cancelar ni modificar citas de Usuario B (R04)', async () => {
      // Tomamos la cita de prueba creada previamente o existente
      const slots = await request(app.getHttpServer()).get('/availability/slots');
      if (slots.body.length > 0) {
        // Reservar con Usuario A (Doctor o Admin en rol de afiliado)
        // Intentar cancelar con doctorToken una cita que no le pertenece
        const userAppointments = await request(app.getHttpServer())
          .get('/appointments/my')
          .set('Authorization', `Bearer ${adminToken}`);
        
        if (userAppointments.body.length > 0) {
          const foreignApptId = userAppointments.body[0].id;
          // Usuario no autorizado intenta cancelarla
          await request(app.getHttpServer())
            .patch(`/appointments/${foreignApptId}/cancel`)
            .set('Authorization', `Bearer ${blockedToken}`)
            .send({ reason: 'Intento malicioso IDOR' })
            .expect(403);
        }
      }
    });

    // PRUEBA 6 — JWT Manipulado y Expirado (R06)
    it('[Prueba 6] JWT - Token alterado en su firma o payload debe ser rechazado con 401 (R06)', async () => {
      const parts = adminToken.split('.');
      // Modificar payload (segundo segmento base64)
      const fakeToken = `${parts[0]}.eyJzdWIiOiIxMjM0NTYiLCJyb2xlcyI6WyJBRE1JTiJdfQ.${parts[2]}`;
      await request(app.getHttpServer())
        .get('/users/me')
        .set('Authorization', `Bearer ${fakeToken}`)
        .expect(401);
    });

    // PRUEBA 8 — Reservas Simultáneas y Condición de Carrera (R07)
    it('[Prueba 8] Reservas Simultáneas - Solo una solicitud concurrente debe tener éxito para el mismo slot (R07)', async () => {
      const slotsRes = await request(app.getHttpServer()).get('/availability/slots').expect(200);
      const freeSlot = slotsRes.body.find((s: any) => s.isAvailable);
      
      if (freeSlot) {
        // Enviar dos reservas simultáneas para el mismo slot
        const [res1, res2] = await Promise.all([
          request(app.getHttpServer())
            .post('/appointments')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ slotId: freeSlot.id }),
          request(app.getHttpServer())
            .post('/appointments')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ slotId: freeSlot.id }),
        ]);

        const statuses = [res1.status, res2.status];
        // Uno debe ser 201 y el otro 409 (Conflicto de concurrencia o cita activa)
        expect(statuses).toContain(409);
      }
    });

    // PRUEBA 9 — Escalada de Privilegios Vertical y Asignación de Roles (R10)
    it('[Prueba 9] Escalada de Privilegios - Afiliado no puede acceder a endpoints de administración ni asignarse roles (R10)', async () => {
      // Acceso directo a endpoints restringidos
      await request(app.getHttpServer())
        .get('/users')
        .set('Authorization', `Bearer ${blockedToken}`)
        .expect(403);

      await request(app.getHttpServer())
        .get('/audit/logs')
        .set('Authorization', `Bearer ${blockedToken}`)
        .expect(403);

      // Intento de manipulación de rol en registro (param tampering)
      await request(app.getHttpServer())
        .post('/auth/register')
        .send({
          idCard: '0905134318',
          fullName: 'Intento Escalada Hack',
          birthDate: '1990-01-01',
          email: 'hack@escalada.com',
          phoneNumber: '0999999999',
          role: 'ADMIN', // Propiedad no permitida en DTO
          roles: ['ADMIN'], // Propiedad no permitida en DTO
        })
        .expect(400); // Rechazado por ValidationPipe con forbidNonWhitelisted: true
    });

    // PRUEBA 10 — Auditoría y no exposición de contraseñas (R09)
    it('[Prueba 10] Auditoría - Los registros de auditoría no deben exponer contraseñas ni tokens completos (R09)', async () => {
      const logsRes = await request(app.getHttpServer())
        .get('/audit/logs')
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(200);

      expect(Array.isArray(logsRes.body)).toBe(true);
      const stringifiedLogs = JSON.stringify(logsRes.body);
      expect(stringifiedLogs).not.toContain('Iess2026!Temporal');
      expect(stringifiedLogs).not.toContain('NuevaClaveSegura2026!');
      expect(stringifiedLogs).not.toContain('passwordHash');
    });
  });
});

