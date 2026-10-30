import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import 'package:iess_turnos_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:iess_turnos_app/features/appointments/viewmodels/appointments_viewmodel.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static String _roleLabel(String role) {
    switch (role) {
      case 'AFFILIATE':     return 'Afiliado';
      case 'REPRESENTATIVE': return 'Representante';
      case 'RECEPTIONIST':  return 'Recepcionista';
      case 'DOCTOR':        return 'Médico';
      case 'ADMIN':         return 'Administrador';
      case 'SUPPORT':       return 'Soporte';
      default:              return role;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'SCHEDULED':   return 'Programada';
      case 'RESCHEDULED': return 'Reprogramada';
      case 'CANCELLED':   return 'Cancelada';
      case 'COMPLETED':   return 'Completada';
      case 'NO_SHOW':     return 'Inasistencia';
      default:            return status;
    }
  }
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(appointmentsProvider.notifier).fetchMyAppointments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final appointmentsState = ref.watch(appointmentsProvider);
    final user = authState.user;
    final nextAppt = appointmentsState.nextAppointment;

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
        onRefresh: () =>
            ref.read(appointmentsProvider.notifier).fetchMyAppointments(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Saludo al usuario y rol
                  Card(
                    color: AppTheme.primaryBlue,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bienvenido(a),',
                                      style: TextStyle(
                                        color: Colors.blue.shade100,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      user?.fullName ?? 'Afiliado Titular',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Chip(
                                label: Text(
                                  _roleLabel(user?.roles.first ?? 'AFFILIATE'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Colors.white.withOpacity(0.9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Cédula: ${user?.idCard ?? ""}',
                            style: TextStyle(
                              color: Colors.blue.shade100,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tarjeta Próxima Cita Médica
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (appointmentsState.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (nextAppt != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nextAppt.specialtyName,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(_statusLabel(nextAppt.status)),
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
                                  'Fecha: ${DateFormat('EEEE d MMMM yyyy, HH:mm', 'es').format(nextAppt.scheduledAt)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Establecimiento: ${nextAppt.facilityName}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  'Médico: ${nextAppt.doctorName}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      context.push('/my-appointments'),
                                  icon: const Icon(Icons.manage_history),
                                  label: const Text(
                                    'Gestionar Cita (Cancelar / Reprogramar)',
                                  ),
                                ),
                              ],
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Text(
                                'No mantiene citas médicas activas en este momento.',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Accesos Rápidos
                  Text(
                    'Acciones Principales',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: MediaQuery.of(context).size.width > 600
                        ? 3
                        : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
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
                      if (user?.isAdmin == true || user?.isReceptionist == true)
                        _buildActionCard(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Administración',
                          subtitle: 'Panel operativo y de control',
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
