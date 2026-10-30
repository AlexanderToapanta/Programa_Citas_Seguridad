import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import 'package:iess_turnos_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:iess_turnos_app/features/appointments/viewmodels/appointments_viewmodel.dart';
import 'package:iess_turnos_app/shared/models/models.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // ─── Traducción de roles ────────────────────────────────────────────────────
  static String _rolLabel(String role) {
    switch (role) {
      case 'AFFILIATE':
        return 'Afiliado';
      case 'REPRESENTATIVE':
        return 'Representante';
      case 'RECEPTIONIST':
        return 'Recepcionista';
      case 'DOCTOR':
        return 'Médico';
      case 'ADMIN':
        return 'Administrador';
      case 'SUPPORT':
        return 'Soporte';
      default:
        return role;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'SCHEDULED':
        return 'Programada';
      case 'RESCHEDULED':
        return 'Reprogramada';
      case 'CANCELLED':
        return 'Cancelada';
      case 'COMPLETED':
        return 'Completada';
      case 'NO_SHOW':
        return 'Inasistencia';
      default:
        return status;
    }
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    // Solo cargar citas para pacientes/afiliados/representantes y médicos
    if (user != null &&
        (user.isAffiliate ||
            user.roles.contains('REPRESENTATIVE') ||
            user.isDoctor)) {
      Future.microtask(
        () => ref.read(appointmentsProvider.notifier).fetchMyAppointments(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IESS - Turnos de Salud'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi Perfil',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (user != null && (user.isAffiliate || user.isDoctor)) {
            await ref.read(appointmentsProvider.notifier).fetchMyAppointments();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Encabezado de bienvenida ─────────────────────────────
                  _buildWelcomeCard(user),
                  const SizedBox(height: 20),

                  // ── Contenido según rol ──────────────────────────────────
                  if (user?.isAdmin == true)
                    _buildAdminView()
                  else if (user?.isSupport == true)
                    _buildSupportView()
                  else if (user?.isDoctor == true)
                    _buildDoctorView()
                  else if (user?.isReceptionist == true)
                    _buildReceptionView()
                  else
                    _buildAffiliateView(), // Afiliado / Representante
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Tarjeta de bienvenida (común a todos) ──────────────────────────────────
  Widget _buildWelcomeCard(UserModel? user) {
    final role = user?.roles.isNotEmpty == true
        ? user!.roles.first
        : 'AFFILIATE';

    return Card(
      color: AppTheme.primaryBlue,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 26,
              child: Icon(Icons.person, color: AppTheme.primaryBlue, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bienvenido(a),',
                    style: TextStyle(color: Colors.blue.shade100, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.fullName ?? '—',
                    softWrap: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cédula: ${user?.idCard ?? ''}',
                    style: TextStyle(color: Colors.blue.shade100, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      _rolLabel(role),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.9),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── VISTA: AFILIADO / REPRESENTANTE ───────────────────────────────────────
  Widget _buildAffiliateView() {
    final appointmentsState = ref.watch(appointmentsProvider);
    final nextAppt = appointmentsState.nextAppointment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Próxima cita
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: nextAppt != null
                          ? AppTheme.primaryBlue
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Próxima Cita Programada',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (appointmentsState.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (nextAppt != null)
                  _buildNextAppointmentDetail(nextAppt)
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No mantiene citas médicas activas en este momento.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Acciones
        Text(
          'Acciones Principales',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 205,
          children: [
            _buildActionCard(
              icon: Icons.add_circle_outline,
              title: 'Reservar Cita',
              subtitle: 'Buscar especialidad y fecha',
              color: AppTheme.primaryBlue,
              onTap: () => context.push('/book-appointment'),
            ),
            _buildActionCard(
              icon: Icons.event_note,
              title: 'Mis Citas',
              subtitle: 'Consultar y reprogramar',
              color: AppTheme.secondaryBlue,
              onTap: () => context.push('/my-appointments'),
            ),
            _buildActionCard(
              icon: Icons.family_restroom,
              title: 'Familiares',
              subtitle: 'Autorizaciones para terceros',
              color: Colors.teal.shade700,
              onTap: () => context.push('/representatives'),
            ),
            _buildActionCard(
              icon: Icons.person_pin,
              title: 'Mi Perfil',
              subtitle: 'Datos de cuenta y clave',
              color: Colors.blueGrey.shade700,
              onTap: () => context.push('/profile'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNextAppointmentDetail(AppointmentModel appt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                appt.specialtyName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            Chip(
              label: Text(_statusLabel(appt.status)),
              backgroundColor: AppTheme.lightBlue,
              labelStyle: const TextStyle(
                color: AppTheme.primaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Fecha: ${DateFormat('EEEE d MMMM yyyy, HH:mm', 'es').format(appt.scheduledAt)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Establecimiento: ${appt.facilityName}',
          style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
        ),
        Text(
          'Médico: ${appt.doctorName}',
          style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push('/my-appointments'),
          icon: const Icon(Icons.manage_history),
          label: const Text('Gestionar Cita (Cancelar / Reprogramar)'),
        ),
      ],
    );
  }

  // ─── VISTA: MÉDICO ──────────────────────────────────────────────────────────
  Widget _buildDoctorView() {
    final state = ref.watch(appointmentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mis Citas Asignadas',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        if (state.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (state.myAppointments.isEmpty)
          Card(
            child: const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No tiene citas asignadas en este momento.',
                  style: TextStyle(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.myAppointments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final appt = state.myAppointments[idx];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              appt.specialtyName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          _buildStatusChip(appt.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.person,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Paciente: ${appt.affiliateName}' +
                                  (appt.affiliateIdCard.isNotEmpty
                                      ? ' · ${appt.affiliateIdCard}'
                                      : ''),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.schedule,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              DateFormat(
                                'EEEE d MMMM yyyy, HH:mm',
                                'es',
                              ).format(appt.scheduledAt),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              appt.facilityName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.person_pin,
          title: 'Mi Perfil',
          subtitle: 'Datos de cuenta y clave',
          color: Colors.blueGrey.shade700,
          onTap: () => context.push('/profile'),
        ),
      ],
    );
  }

  // ─── VISTA: RECEPCIONISTA ───────────────────────────────────────────────────
  Widget _buildReceptionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Acciones de Recepción',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 205,
          children: [
            _buildActionCard(
              icon: Icons.calendar_view_month,
              title: 'Todas las Citas',
              subtitle: 'Ver y gestionar turnos del día',
              color: AppTheme.primaryBlue,
              onTap: () => context.push('/reception-appointments'),
            ),
            _buildActionCard(
              icon: Icons.person_pin,
              title: 'Mi Perfil',
              subtitle: 'Datos de cuenta y clave',
              color: Colors.blueGrey.shade700,
              onTap: () => context.push('/profile'),
            ),
          ],
        ),
      ],
    );
  }

  // ─── VISTA: ADMINISTRADOR ───────────────────────────────────────────────────
  Widget _buildAdminView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Panel Administrativo',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 205,
          children: [
            _buildActionCard(
              icon: Icons.manage_accounts,
              title: 'Gestión de Usuarios',
              subtitle: 'Ver y administrar usuarios del sistema',
              color: Colors.indigo.shade800,
              onTap: () => context.push('/admin'),
            ),
            _buildActionCard(
              icon: Icons.person_pin,
              title: 'Mi Perfil',
              subtitle: 'Datos de cuenta y clave',
              color: Colors.blueGrey.shade700,
              onTap: () => context.push('/profile'),
            ),
          ],
        ),
      ],
    );
  }

  // ─── VISTA: SOPORTE ─────────────────────────────────────────────────────────
  Widget _buildSupportView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Módulo de Soporte',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 205,
          children: [
            _buildActionCard(
              icon: Icons.security,
              title: 'Registros de Auditoría',
              subtitle: 'Revisar logs del sistema (RF09)',
              color: Colors.orange.shade700,
              onTap: () => context.push('/support'),
            ),
            _buildActionCard(
              icon: Icons.person_pin,
              title: 'Mi Perfil',
              subtitle: 'Datos de cuenta y clave',
              color: Colors.blueGrey.shade700,
              onTap: () => context.push('/profile'),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tarjeta de acción (compartida) ────────────────────────────────────────
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Chip de estado de cita ─────────────────────────────────────────────────
  Widget _buildStatusChip(String status) {
    Color bg = AppTheme.lightBlue;
    Color fg = AppTheme.primaryBlue;

    if (status == 'CANCELLED') {
      bg = Colors.red.shade50;
      fg = AppTheme.errorRed;
    } else if (status == 'COMPLETED') {
      bg = Colors.green.shade50;
      fg = AppTheme.successGreen;
    } else if (status == 'NO_SHOW') {
      bg = Colors.orange.shade50;
      fg = AppTheme.warningOrange;
    } else if (status == 'RESCHEDULED') {
      bg = Colors.purple.shade50;
      fg = Colors.purple.shade700;
    }

    return Chip(
      label: Text(_statusLabel(status)),
      backgroundColor: bg,
      labelStyle: TextStyle(
        color: fg,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
