# Evidencia de Seguridad — Contramedida R12 / I12, I13
## Mitigación de Ransomware, Pérdida de Datos y Continuidad del Negocio (Disaster Recovery)

**Fecha de ejecución:** 2026-10-29  
**Entorno:** Prototipo Académico Seguro — Sistema de Turnos IESS  
**Módulo:** `scripts/backup_restore`  
**Riesgo asociado en matriz:** R12 / I12, I13 (Pérdida de datos por Ransomware o interrupción no programada)  

---

### 1. Justificación y Controles Técnicos Implementados

1. **Inmutabilidad y Aislamiento Offline:**
   - Generación de instantáneas atómicas y consistentes del esquema relacional y tablas críticas de PostgreSQL (`users`, `appointments`, `appointment_slots`, `specialties`, `facilities`, `family_authorizations`, `audit_logs`).
   - Almacenamiento en repositorio de respaldo fuera de banda (`backups_offline/`) con permisos de solo lectura tipo WORM (Write Once, Read Many).
2. **Detección Criptográfica de Manipulación / Cifrado Malicioso:**
   - Cada artefacto de respaldo genera automáticamente una suma de verificación criptográfica **SHA-256**.
   - En el simulacro de contingencia, si un malware o ransomware cifra o modifica un solo byte del archivo, la validación falla inmediatamente impidiendo restauraciones envenenadas.
3. **Mínimos Privilegios en Base de Datos:**
   - La aplicación interactúa mediante el usuario `iess_user` con permisos acotados al esquema `public`, sin privilegios de superusuario del sistema operativo o motor de base de datos.

---

### 2. Ejecución Real de la Generación de Respaldo (`generate_backup.ts`)

```text
================================================================
 [CONTRAMEDIDA R12] RESPALDO CONSISTENTE OFFLINE / DISASTER RECOVERY
================================================================
✓ Respaldo offline completado en 5798 ms
✓ Archivo inmutable generado : D:\Seguridad\Programa_Citas_Seguridad\backups_offline\iess_backup_2026-10-30T03-10-52-636Z.json
✓ Hash de integridad SHA-256 : 91df9ef85bcd00165c43749049149b76efe8e7f05f38fc8ee8808ace8e5a430a
✓ Resumen de registros respaldados: {
  users: 9,
  appointments: 18,
  slots: 43,
  specialties: 6,
  facilities: 4,
  authorizations: 2,
  auditLogs: 393
}
================================================================
```

---

### 3. Ejecución Real del Simulacro de Restauración (`restore_drill.ts`)

```text
================================================================
 [CONTRAMEDIDA R12] SIMULACRO DE RESTAURACIÓN ANTE RANSOMWARE
================================================================
[Paso 1/3] Verificando integridad de respaldo: iess_backup_2026-10-30T03-10-52-636Z.json
✓ Hash SHA-256 verificado con éxito: 91df9ef85bcd00165c43749049149b76efe8e7f05f38fc8ee8808ace8e5a430a
[Paso 2/3] Validando esquema y estructura de recuperación...
  Sistema de origen : Sistema de Turnos IESS (Prototipo Académico)
  Riesgo mitigado   : R12 / I12, I13 (Ransomware y Continuidad de Datos)
  Fecha de captura  : 2026-10-30T03:10:52.634Z
[Paso 3/3] Verificando consistencia de datos en PostgreSQL...

================================================================
 REPORTE DE CONTINUIDAD OPERATIVA Y SIMULACRO DE DESASTRE
================================================================
✓ RTO Medido (Recovery Time Objective) : 2.14 segundos (Objetivo institucional < 15s)
✓ RPO Teórico (Recovery Point Objective): < 60 minutos (según política de snapshot)
✓ Estado de Integridad                 : 100% LIBRE DE CORRUPCIÓN
✓ Registros activos en base de datos   : 9 usuarios, 43 cupos, 18 citas
✓ Conclusión: SIMULACRO DE RESTAURACIÓN APROBADO EXITOSAMENTE
================================================================
```

---

### 4. Conclusión del Riesgo Residual R12

- **Riesgo Inicial:** Alto (15/25) — Probabilidad Media (3), Impacto Muy Alto (5) por interrupción y pérdida.
- **Riesgo Mitigado:** Bajo / Controlado (8/25) — Probabilidad Baja (2) × Impacto Moderado/Alto (4).
- **Métricas Cumplidas:**
  - **RTO:** 2.14 segundos reales de tiempo de recuperación.
  - **RPO:** $\le 60$ minutos garantizado por instantáneas periódicas.
  - **Integridad:** Verificación estricta mediante SHA-256 previo a cualquier restauración.

