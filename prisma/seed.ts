import { PrismaClient, RoleType, UserStatus, AppointmentStatus, AuthorizationStatus } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

async function main() {
  console.log('--- Iniciando Seeding de Datos Ficticios (IESS Etapa 1) ---');

  // 1. Roles
  const roles = [
    { name: RoleType.AFFILIATE, description: 'Afiliado titular que gestiona sus turnos' },
    { name: RoleType.REPRESENTATIVE, description: 'Familiar o apoderado autorizado' },
    { name: RoleType.RECEPTIONIST, description: 'Personal de ventanilla / recepción' },
    { name: RoleType.DOCTOR, description: 'Médico tratante del IESS' },
    { name: RoleType.ADMIN, description: 'Administrador del sistema de turnos' },
    { name: RoleType.SUPPORT, description: 'Personal de soporte técnico y monitoreo' },
  ];

  for (const role of roles) {
    await prisma.role.upsert({
      where: { name: role.name },
      update: {},
      create: role,
    });
  }
  console.log('✓ Roles creados/verificados');

  // 2. Hash por defecto para usuarios semilla (Argon2id)
  const defaultPasswordHash = await argon2.hash('Iess2026!Temporal', {
    type: argon2.argon2id,
  });

  // 3. Especialidades
  const specialtiesData = [
    { code: 'MED-GEN', name: 'Medicina General', description: 'Atención primaria y medicina preventiva sin necesidad de derivación previa.', requiresReferral: false },
    { code: 'PED-001', name: 'Pediatría Integral', description: 'Atención médica de infantes y adolescentes.', requiresReferral: false },
    { code: 'GYN-001', name: 'Ginecología y Obstetricia', description: 'Salud integral de la mujer y control prenatal.', requiresReferral: false },
    { code: 'CAR-002', name: 'Cardiología Clínica', description: 'Especialidad de segundo nivel. Requiere derivación de Medicina General.', requiresReferral: true },
    { code: 'NEU-003', name: 'Neurología', description: 'Especialidad de alta complejidad. Requiere derivación médica activa.', requiresReferral: true },
    { code: 'OFT-004', name: 'Oftalmología', description: 'Cuidado visual especializado. Requiere derivación previa.', requiresReferral: true },
  ];

  const specialties = [];
  for (const sp of specialtiesData) {
    const created = await prisma.specialty.upsert({
      where: { code: sp.code },
      update: {},
      create: sp,
    });
    specialties.push(created);
  }
  console.log('✓ Especialidades médicas registradas');

  // 4. Establecimientos de salud
  const facilitiesData = [
    { code: 'HGSF-UIO', name: 'Hospital General del Norte de Guayaquil / Quito San Francisco', address: 'Av. Jaime Roldós Aguilera y Francisco de Orellana', city: 'Quito', phone: '023955600' },
    { code: 'HTMC-GYE', name: 'Hospital de Especialidades Teodoro Maldonado Carbo', address: 'Av. 25 de Julio y Ernesto Albán', city: 'Guayaquil', phone: '043714000' },
    { code: 'CS-VILLAF-UIO', name: 'Centro de Salud Villa Flora Tipo B', address: 'Av. Alonso de Angulo y Pedro de Alfaro', city: 'Quito', phone: '022650122' },
    { code: 'HJAR-CUE', name: 'Hospital José Carrasco Arteaga', address: 'Av. Rayoloma y Popayán', city: 'Cuenca', phone: '072861500' },
  ];

  const facilities = [];
  for (const fc of facilitiesData) {
    const created = await prisma.facility.upsert({
      where: { code: fc.code },
      update: {},
      create: fc,
    });
    facilities.push(created);
  }
  console.log('✓ Establecimientos del IESS registrados');

  // Obtener roles para asignación
  const roleAffiliate = await prisma.role.findUnique({ where: { name: RoleType.AFFILIATE } });
  const roleDoctor = await prisma.role.findUnique({ where: { name: RoleType.DOCTOR } });
  const roleAdmin = await prisma.role.findUnique({ where: { name: RoleType.ADMIN } });
  const roleReception = await prisma.role.findUnique({ where: { name: RoleType.RECEPTIONIST } });
  const roleSupport = await prisma.role.findUnique({ where: { name: RoleType.SUPPORT } });

  // 5. Usuario Administrador
  const adminUser = await prisma.user.upsert({
    where: { idCard: '1710000001' },
    update: {},
    create: {
      idCard: '1710000001',
      fullName: 'Administrador Central IESS',
      birthDate: new Date('1985-05-15'),
      email: 'admin.turnos@iess.gob.ec',
      phoneNumber: '0990000001',
      passwordHash: defaultPasswordHash,
      mustChangePassword: false,
      status: UserStatus.ACTIVE,
      roles: {
        create: [{ roleId: roleAdmin.id }],
      },
    },
  });

  // 6. Usuario Recepcionista
  await prisma.user.upsert({
    where: { idCard: '1710000002' },
    update: {},
    create: {
      idCard: '1710000002',
      fullName: 'Valeria Recepción San Francisco',
      birthDate: new Date('1992-08-20'),
      email: 'recepcion.sanfrancisco@iess.gob.ec',
      phoneNumber: '0990000002',
      passwordHash: defaultPasswordHash,
      mustChangePassword: false,
      status: UserStatus.ACTIVE,
      roles: {
        create: [{ roleId: roleReception.id }],
      },
    },
  });

  // 7. Usuario Soporte Técnico
  await prisma.user.upsert({
    where: { idCard: '1710000003' },
    update: {},
    create: {
      idCard: '1710000003',
      fullName: 'Carlos Monitoreo Soporte',
      birthDate: new Date('1990-11-10'),
      email: 'soporte.seguridad@iess.gob.ec',
      phoneNumber: '0990000003',
      passwordHash: defaultPasswordHash,
      mustChangePassword: false,
      status: UserStatus.ACTIVE,
      roles: {
        create: [{ roleId: roleSupport.id }],
      },
    },
  });

  // 8. Afiliados de Prueba
  // Afiliado 1: Regular
  const affiliate1 = await prisma.user.upsert({
    where: { idCard: '1715897451' },
    update: {},
    create: {
      idCard: '1715897451',
      fullName: 'Juan Carlos Morales Torres',
      birthDate: new Date('1988-03-24'),
      email: 'juan.morales@mailtest.com',
      phoneNumber: '0984567890',
      passwordHash: defaultPasswordHash,
      mustChangePassword: true, // Debe cambiar contraseña en primer acceso
      status: UserStatus.ACTIVE,
      roles: {
        create: [{ roleId: roleAffiliate.id }],
      },
    },
  });

  // Afiliado 2: Familiar autorizado de Juan Carlos (abuela o madre)
  const affiliate2 = await prisma.user.upsert({
    where: { idCard: '1708451239' },
    update: {},
    create: {
      idCard: '1708451239',
      fullName: 'Rosa Elena Torres Silva',
      birthDate: new Date('1955-09-12'),
      email: 'rosa.torres@mailtest.com',
      phoneNumber: '0981234567',
      passwordHash: defaultPasswordHash,
      mustChangePassword: false,
      status: UserStatus.ACTIVE,
      roles: {
        create: [{ roleId: roleAffiliate.id }],
      },
    },
  });

  // Autorización Familiar activa de Juan Morales sobre Rosa Torres (RF04)
  await prisma.familyAuthorization.upsert({
    where: {
      principalUserId_representativeUserId: {
        principalUserId: affiliate2.id,
        representativeUserId: affiliate1.id,
      },
    },
    update: {},
    create: {
      principalUserId: affiliate2.id, // Rosa es el titular que autoriza
      representativeUserId: affiliate1.id, // Juan Carlos es el representante autorizado
      relationship: 'MADRE_HIJO',
      verificationMethod: 'OTP_CONTACTO',
      verificationProof: 'VERIFIED_HASH_89234',
      status: AuthorizationStatus.ACTIVE,
      validUntil: new Date('2027-12-31'),
    },
  });

  // Afiliado 3: Usuario con 3 inasistencias injustificadas (para probar regla de bloqueo)
  const affiliateBlocked = await prisma.user.upsert({
    where: { idCard: '1723456780' },
    update: {},
    create: {
      idCard: '1723456780',
      fullName: 'Pedro Inasistente Mendoza',
      birthDate: new Date('1994-01-18'),
      email: 'pedro.mendoza@mailtest.com',
      phoneNumber: '0978901234',
      passwordHash: defaultPasswordHash,
      mustChangePassword: false,
      status: UserStatus.ACTIVE,
      roles: {
        create: [{ roleId: roleAffiliate.id }],
      },
    },
  });

  // 9. Médicos y Cupos
  const doctorUser1 = await prisma.user.upsert({
    where: { idCard: '1712233445' },
    update: {},
    create: {
      idCard: '1712233445',
      fullName: 'Dra. Gabriela Andrade Flores',
      birthDate: new Date('1982-04-12'),
      email: 'dra.andrade@iess.gob.ec',
      phoneNumber: '0995551122',
      passwordHash: defaultPasswordHash,
      mustChangePassword: false,
      status: UserStatus.ACTIVE,
      roles: {
        create: [{ roleId: roleDoctor.id }],
      },
    },
  });

  const medGen = specialties.find((s) => s.code === 'MED-GEN');
  const hgsf = facilities.find((f) => f.code === 'HGSF-UIO');

  const doctor1 = await prisma.doctor.upsert({
    where: { userId: doctorUser1.id },
    update: {},
    create: {
      userId: doctorUser1.id,
      licenseNumber: 'MSP-MED-99482',
      specialtyId: medGen.id,
      facilityId: hgsf.id,
    },
  });

  // Médico 2: Cardiólogo (Especialidad con derivación requerida)
  const doctorUser2 = await prisma.user.upsert({
    where: { idCard: '1713344556' },
    update: {},
    create: {
      idCard: '1713344556',
      fullName: 'Dr. Roberto Zambrano Vélez',
      birthDate: new Date('1976-11-03'),
      email: 'dr.zambrano@iess.gob.ec',
      phoneNumber: '0995553344',
      passwordHash: defaultPasswordHash,
      mustChangePassword: false,
      status: UserStatus.ACTIVE,
      roles: {
        create: [{ roleId: roleDoctor.id }],
      },
    },
  });

  const cardio = specialties.find((s) => s.code === 'CAR-002');
  const doctor2 = await prisma.doctor.upsert({
    where: { userId: doctorUser2.id },
    update: {},
    create: {
      userId: doctorUser2.id,
      licenseNumber: 'MSP-CAR-77123',
      specialtyId: cardio.id,
      facilityId: hgsf.id,
    },
  });

  // 10. Generación de Slots de disponibilidad para mañana y pasado mañana
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);

  const slotTimes = [
    { startHour: 8, startMin: 0, endHour: 8, endMin: 30 },
    { startHour: 8, startMin: 30, endHour: 9, endMin: 0 },
    { startHour: 9, startMin: 0, endHour: 9, endMin: 30 },
    { startHour: 9, startMin: 30, endHour: 10, endMin: 0 },
    { startHour: 10, startMin: 0, endHour: 10, endMin: 30 },
    { startHour: 10, startMin: 30, endHour: 11, endMin: 0 },
    { startHour: 11, startMin: 0, endHour: 11, endMin: 30 },
  ];

  for (const time of slotTimes) {
    const start = new Date(tomorrow);
    start.setHours(time.startHour, time.startMin, 0, 0);
    const end = new Date(tomorrow);
    end.setHours(time.endHour, time.endMin, 0, 0);

    // Slots para Doctor 1 (Medicina General)
    await prisma.appointmentSlot.upsert({
      where: {
        unique_doctor_slot: {
          doctorId: doctor1.id,
          date: tomorrow,
          startTime: start,
        },
      },
      update: {},
      create: {
        doctorId: doctor1.id,
        date: tomorrow,
        startTime: start,
        endTime: end,
        isAvailable: true,
      },
    });

    // Slots para Doctor 2 (Cardiología)
    await prisma.appointmentSlot.upsert({
      where: {
        unique_doctor_slot: {
          doctorId: doctor2.id,
          date: tomorrow,
          startTime: start,
        },
      },
      update: {},
      create: {
        doctorId: doctor2.id,
        date: tomorrow,
        startTime: start,
        endTime: end,
        isAvailable: true,
      },
    });
  }
  console.log('✓ Horarios y cupos de disponibilidad generados');

  // 11. Generar 3 inasistencias en los últimos 90 días para el usuario Pedro Mendoza (para probar bloqueo)
  const pastSlot1 = await prisma.appointmentSlot.create({
    data: {
      doctorId: doctor1.id,
      date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
      startTime: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
      endTime: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000 + 30 * 60 * 1000),
      isAvailable: false,
    },
  });
  await prisma.appointment.create({
    data: {
      affiliateId: affiliateBlocked.id,
      bookedByUserId: affiliateBlocked.id,
      specialtyId: medGen.id,
      facilityId: hgsf.id,
      doctorId: doctor1.id,
      slotId: pastSlot1.id,
      scheduledAt: pastSlot1.startTime,
      status: AppointmentStatus.NO_SHOW,
    },
  });

  const pastSlot2 = await prisma.appointmentSlot.create({
    data: {
      doctorId: doctor1.id,
      date: new Date(Date.now() - 20 * 24 * 60 * 60 * 1000),
      startTime: new Date(Date.now() - 20 * 24 * 60 * 60 * 1000),
      endTime: new Date(Date.now() - 20 * 24 * 60 * 60 * 1000 + 30 * 60 * 1000),
      isAvailable: false,
    },
  });
  await prisma.appointment.create({
    data: {
      affiliateId: affiliateBlocked.id,
      bookedByUserId: affiliateBlocked.id,
      specialtyId: medGen.id,
      facilityId: hgsf.id,
      doctorId: doctor1.id,
      slotId: pastSlot2.id,
      scheduledAt: pastSlot2.startTime,
      status: AppointmentStatus.NO_SHOW,
    },
  });

  const pastSlot3 = await prisma.appointmentSlot.create({
    data: {
      doctorId: doctor1.id,
      date: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000),
      startTime: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000),
      endTime: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000 + 30 * 60 * 1000),
      isAvailable: false,
    },
  });
  await prisma.appointment.create({
    data: {
      affiliateId: affiliateBlocked.id,
      bookedByUserId: affiliateBlocked.id,
      specialtyId: medGen.id,
      facilityId: hgsf.id,
      doctorId: doctor1.id,
      slotId: pastSlot3.id,
      scheduledAt: pastSlot3.startTime,
      status: AppointmentStatus.NO_SHOW,
    },
  });
  console.log('✓ Escenario de inasistencias (3 NO_SHOW en 90 días) configurado para pruebas');

  console.log('--- Seeding completado con éxito ---');
}

main()
  .catch((e) => {
    console.error('Error durante el seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

