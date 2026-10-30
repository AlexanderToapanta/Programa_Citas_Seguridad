# Sistema de Turnos Médicos IESS — Backend API (Etapa 1)

Este proyecto corresponde a la **Etapa 1: Arquitectura y Backend Seguro** del prototipo universitario de gestión de turnos médicos del Instituto Ecuatoriano de Seguridad Social (IESS).

> [!NOTE]
> **Aclaración Académica:** Este es un proyecto de carácter educativo y de investigación en ingeniería de seguridad de software. No es una aplicación oficial del IESS y no interactúa con bases de datos ni servicios reales de pacientes del sistema de salud pública.

---

## 1. Módulos y Arquitectura Implementada

El backend ha sido construido sobre **Node.js 24**, **NestJS 11** y **TypeScript**, utilizando **Prisma ORM** y **PostgreSQL 16**.

### Arquitectura Modular
- **`auth`**: Registro con validación de cédula (algoritmo Módulo 10 del Registro Civil), autenticación con **Argon2id**, generación de credenciales temporales aleatorias con expiración estricta de 15 minutos, cambio obligatorio de contraseña en el primer acceso (`mustChangePassword`), control de intentos fallidos (bloqueo progresivo ante fuerza bruta) y lista de revocación de tokens JWT (`revoked_tokens`).
- **`users`**: Gestión de perfiles y usuarios con estricto principio de minimización de datos (LOPDP Ecuador), eliminando campos laborales o sensibles innecesarios.
- **`roles`**: Control de acceso basado en roles (RBAC) con discriminación contextual (`AFFILIATE`, `REPRESENTATIVE`, `RECEPTIONIST`, `DOCTOR`, `ADMIN`, `SUPPORT`).
- **`specialties`**: Catálogo de especialidades médicas con bandera de derivación requerida (`requiresReferral`).
- **`facilities`**: Red de hospitales y centros de salud del IESS.
- **`availability`**: Horarios de profesionales médicos y cupos organizados con versión para *optimistic locking* y restricción de unicidad física.
- **`appointments`**: Motor central de reglas de negocio para reservas, reprogramaciones y cancelaciones:
  - **Doble reserva prevenida:** Transacciones atómicas de base de datos con control de concurrencia y restricción única sobre `slot_id`.
  - **Cita activa única:** Comprobación estricta que impide que un afiliado mantenga más de una cita pendiente al mismo tiempo.
  - **Inasistencias injustificadas:** Bloqueo automático de reserva en línea para afiliados con 3 o más faltas (`NO_SHOW`) en los últimos 90 días.
  - **Ventana de reprogramación:** Mínimo 8 horas de anticipación requeridas.
  - **Cancelación:** Permitida en cualquier momento antes del inicio del turno.
- **`representatives`**: Delegación de gestión de citas para familiares (menores o adultos mayores) mediante autorizaciones verificables (código dactilar / OTP / tutoría asistida), evitando que cualquiera reserve solo con cédula y fecha de nacimiento.
- **`integrations`**: Simulación modular y resiliente (con circuit breaker) de los servicios institucionales del IESS (afiliación activa y derivaciones médicas de Medicina General a especialidades).
- **`audit`**: Interceptor global y servicio de auditoría inmutable que sanitiza automáticamente cualquier credencial, contraseña o token completo antes de persistir en PostgreSQL.

---

## 2. Requisitos Previos

- **Node.js** v20 o superior (recomendado v24).
- **Docker** y **Docker Compose**.
- **npm** v10 o superior.

---

## 3. Instalación y Puesta en Marcha

### Paso 1: Clonar y configurar variables de entorno
```bash
# Copiar archivo de entorno de ejemplo
cp .env.example .env
```

### Paso 2: Iniciar Base de Datos con Docker Compose
```bash
docker compose up -d postgres
```
*El contenedor PostgreSQL se iniciará en una red interna aislada con volumen persistente en el puerto `5434` (mapeado para pruebas locales).*

### Paso 3: Instalar dependencias
```bash
npm install
```

### Paso 4: Ejecutar migraciones de Prisma y cargar datos ficticios
```bash
# Aplicar esquema en PostgreSQL
npx prisma migrate dev --name init

# Cargar catálogo y usuarios de prueba
npm run prisma:seed
```

### Paso 5: Compilar e Iniciar la API
```bash
# Modo desarrollo con recarga en vivo
npm run start:dev

# O modo producción
npm run build
npm run start:prod
```

La API estará disponible en `http://localhost:3000`.

---

## 4. Documentación Interactiva OpenAPI / Swagger

Una vez iniciado el servidor, accede a la documentación interactiva con capacidad para probar los endpoints:

👉 **[http://localhost:3000/api/docs](http://localhost:3000/api/docs)**

---

## 5. Cuentas de Prueba Preconfiguradas (Seed Data)

Todos los usuarios de prueba tienen la contraseña inicial: `Iess2026!Temporal`

| Rol | Cédula | Nombre Completo | Particularidad |
| :--- | :--- | :--- | :--- |
| **Administrador** | `1710000001` | Administrador Central IESS | Acceso a gestión y logs de auditoría |
| **Recepción** | `1710000002` | Valeria Recepción San Francisco | Gestión operativa presencial |
| **Soporte** | `1710000003` | Carlos Monitoreo Soporte | Monitoreo técnico y trazabilidad |
| **Médico (Medicina General)** | `1712233445` | Dra. Gabriela Andrade Flores | Visualiza solo sus pacientes asignados |
| **Médico (Cardiología)** | `1713344556` | Dr. Roberto Zambrano Vélez | Especialidad que requiere derivación médica |
| **Afiliado Titular** | `1715897451` | Juan Carlos Morales Torres | Debe cambiar contraseña en 1er acceso (`mustChangePassword: true`) |
| **Familiar Representado** | `1708451239` | Rosa Elena Torres Silva | Titular con autorización familiar activa otorgada a Juan Morales |
| **Afiliado Bloqueado** | `1723456780` | Pedro Inasistente Mendoza | Tiene 3 inasistencias en 90 días (reserva en línea bloqueada) |

---

## 6. Ejecución de Pruebas Automatizadas

El proyecto incluye dos suites de pruebas completas:

### 1. Pruebas Unitarias de Seguridad y Criptografía
Verifican el algoritmo Módulo 10 ecuatoriano, generación no determinista de credenciales temporales y algoritmo Argon2id:
```bash
npx jest test/crypto.spec.ts --rootDir=.
```

### 2. Pruebas End-to-End, de Reglas de Negocio y Seguridad Especializada (Etapa 3)
Verifican salud del sistema, autenticación, protección contra fuerza bruta y DoS (Rate Limiting HTTP 429), aislamiento de roles RBAC, prevención de reservas duplicadas (concurrencia atómica), bloqueo por 3 inasistencias, regla de cita activa única, autorización familiar IDOR/BOLA, inyecciones SQL controladas, integridad de firma JWT y auditoría sanitizada sin contraseñas:
```bash
npm run test:e2e
```

**Resultado obtenido en la suite backend (24/24 pruebas aprobadas):**
```text
PASS test/iess-turnos.e2e-spec.ts (17.269 s)
  Suite de Integración y Reglas de Negocio - Sistema de Turnos IESS (RF01 - RF11)
    1. Verificación de Salud del Sistema (Health Check - RF11)
      √ GET /health - debe responder con estado healthy y conexión activa a base de datos
    2. Autenticación y Credenciales Temporales (RF02, RF05, R03)
      √ POST /auth/register - debe registrar un usuario válido y generar credencial temporal de 15 minutos
      √ POST /auth/login - debe rechazar contraseña errónea con HTTP 401 sin enumerar cuentas (R03)
      √ POST /auth/login y flujo de primer acceso (mustChangePassword) - debe obligar el cambio de contraseña
    3. Control de Acceso por Roles (RBAC - RF06, R10)
      √ GET /users - debe ser denegado a un afiliado regular (HTTP 403)
      √ GET /users - debe ser permitido a un administrador (HTTP 200)
      √ GET /audit/logs - debe ser denegado a afiliados comunes (HTTP 403) y permitido a administradores
    4. Reglas de Negocio de Citas Médicas (RF01, RF03, R07)
      √ GET /availability/slots - debe listar cupos disponibles con información de doctor y especialidad
      √ POST /appointments - Restricción de 3 inasistencias en 90 días debe bloquear la reserva en línea
      √ POST /appointments - Reserva exitosa de un cupo disponible para el afiliado
      √ POST /appointments - Regla de Cita Activa Única: no puede agendar otra cita si ya tiene una activa
      √ POST /appointments - Prevención de Doble Reserva (Condición de Carrera / R07): no se puede reservar un slot ocupado
      √ GET /appointments/my - Consulta segura con aislamiento IDOR/BOLA (R04)
      √ PATCH /appointments/:id/cancel - Cancelación exitosa de la cita médica antes del inicio
    5. Gestión de Familiares Autorizados y Mitigación IDOR (RF04, R04)
      √ POST /representatives - Otorgar autorización familiar con validación verificable
      √ GET /representatives/my-authorizations - Consultar autorizaciones emitidas
    6. Cierre Seguro de Sesión y Revocación de Tokens (R06)
      √ POST /auth/logout - debe invalidar el token actual en la lista de revocación
    7. Pruebas de Seguridad Especializadas (Etapa 3 - Pruebas 1 a 10)
      √ [Prueba 1] SQL Injection - entradas maliciosas no deben alterar consultas SQL (R05)
      √ [Prueba 3 & 5] DoS y Fuerza Bruta - Throttler debe responder 429 Too Many Requests ante ráfagas (R02, R03)
      √ [Prueba 4] IDOR / BOLA - Usuario A no debe poder cancelar ni modificar citas de Usuario B (R04)
      √ [Prueba 6] JWT - Token alterado en su firma o payload debe ser rechazado con 401 (R06)
      √ [Prueba 8] Reservas Simultáneas - Solo una solicitud concurrente debe tener éxito para el mismo slot (R07)
      √ [Prueba 9] Escalada de Privilegios - Afiliado no puede acceder a endpoints de administración ni asignarse roles (R10)
      √ [Prueba 10] Auditoría - Los registros de auditoría no deben exponer contraseñas ni tokens completos (R09)
```

### 3. Pruebas Unitarias de Seguridad en Frontend (Flutter Test)
Verifican el modelo RBAC en cliente, almacenamiento seguro multiplataforma y la visualización de datos sin ejecución de XSS:
```bash
cd client_flutter
flutter test
```
**Resultado obtenido:**
```text
00:00 +0: Pruebas de Seguridad en Flutter (Etapa 3) 1. Modelo de Usuario y Roles (RBAC en cliente - R10)
00:00 +1: Pruebas de Seguridad en Flutter (Etapa 3) 2. Prevención de XSS - Los datos se manejan como texto plano sin renderizado web ejecutable
00:00 +2: Pruebas de Seguridad en Flutter (Etapa 3) 3. Validación de Almacenamiento Seguro (Instanciación de SecureStorageService)
00:00 +3: All tests passed!
```

---

## 7. Matriz de Seguridad y Cumplimiento LOPDP

- **Argon2id:** Algoritmo ganador de la Password Hashing Competition, resistente a ataques acelerados por GPU y side-channel.
- **Prevención IDOR/BOLA (R04):** Todas las consultas y mutaciones de citas y autorizaciones verifican la identidad del solicitante contra el recurso o mandato vigente en base de datos.
- **Prevención de Inyección SQL (R05):** Consultas 100% parametrizadas a través del motor de Prisma ORM.
- **Protección XSS y Cabeceras (R06):** Integración de `helmet` para forzar CSP, HSTS, X-Content-Type-Options y eliminación de `X-Powered-By`.
- **Sanitización de Auditoría (RF09, R09):** Filtrado recursivo automático en `AuditService` que reemplaza por `[REDACTED_BY_AUDIT_POLICY]` contraseñas, tokens y claves.
