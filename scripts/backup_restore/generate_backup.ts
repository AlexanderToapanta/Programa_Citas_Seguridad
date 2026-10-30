import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

const prisma = new PrismaClient();

async function main() {
  const startTime = Date.now();
  console.log('================================================================');
  console.log(' [CONTRAMEDIDA R12] RESPALDO CONSISTENTE OFFLINE / DISASTER RECOVERY');
  console.log('================================================================');

  const [users, appointments, slots, specialties, facilities, authorizations, auditLogs] = await Promise.all([
    prisma.user.findMany({ include: { roles: { include: { role: true } } } }),
    prisma.appointment.findMany(),
    prisma.appointmentSlot.findMany(),
    prisma.specialty.findMany(),
    prisma.facility.findMany(),
    prisma.familyAuthorization.findMany(),
    prisma.auditLog.findMany(),
  ]);

  const backupData = {
    metadata: {
      system: 'Sistema de Turnos IESS (Prototipo Académico)',
      standard: 'ISO 27001 / BIA / NIST SP 800-34 Rev. 1',
      riskId: 'R12 / I12, I13 (Ransomware y Continuidad de Datos)',
      backupType: 'Full Consistent Snapshot (WORM / Immutable Simulation)',
      generatedAt: new Date().toISOString(),
      rpoEstimate: '< 60 minutes',
      rtoTarget: '< 15 seconds',
    },
    metrics: {
      users: users.length,
      appointments: appointments.length,
      slots: slots.length,
      specialties: specialties.length,
      facilities: facilities.length,
      authorizations: authorizations.length,
      auditLogs: auditLogs.length,
    },
    data: {
      specialties,
      facilities,
      users,
      slots,
      appointments,
      authorizations,
      auditLogs,
    },
  };

  const backupDir = path.resolve(process.cwd(), 'backups_offline');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const jsonPath = path.join(backupDir, `iess_backup_${timestamp}.json`);
  const content = JSON.stringify(backupData, null, 2);
  fs.writeFileSync(jsonPath, content, 'utf8');

  // Calcular Hash criptográfico SHA-256
  const hash = crypto.createHash('sha256').update(content).digest('hex');
  const hashPath = path.join(backupDir, `iess_backup_${timestamp}.sha256`);
  fs.writeFileSync(hashPath, `${hash}  ${path.basename(jsonPath)}\n`, 'utf8');

  // Aplicar permiso de solo lectura simulando inmutabilidad (WORM)
  try {
    fs.chmodSync(jsonPath, 0o444);
    fs.chmodSync(hashPath, 0o444);
  } catch (e) {
    // Si Windows maneja permisos alternativos
  }

  const durationMs = Date.now() - startTime;
  console.log(`✓ Respaldo offline completado en ${durationMs} ms`);
  console.log(`✓ Archivo inmutable generado : ${jsonPath}`);
  console.log(`✓ Hash de integridad SHA-256 : ${hash}`);
  console.log(`✓ Resumen de registros respaldados:`, backupData.metrics);
  console.log('================================================================');
}

main()
  .catch((err) => {
    console.error('Error generando respaldo offline:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

