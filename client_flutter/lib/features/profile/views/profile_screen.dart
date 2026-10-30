import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import 'package:iess_turnos_app/features/auth/viewmodels/auth_viewmodel.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static String _roleLabel(String role) {
    switch (role) {
      case 'AFFILIATE':      return 'Afiliado';
      case 'REPRESENTATIVE': return 'Representante';
      case 'RECEPTIONIST':   return 'Recepcionista';
      case 'DOCTOR':         return 'Médico';
      case 'ADMIN':          return 'Administrador';
      case 'SUPPORT':        return 'Soporte';
      default:               return role;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil de Usuario')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de Identificación
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: AppTheme.lightBlue,
                          child: Icon(
                            Icons.person,
                            size: 48,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user?.fullName ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cédula: ${user?.idCard ?? ""}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: (user?.roles ?? ['AFFILIATE'])
                              .map(
                                (r) => Chip(
                                  label: Text(_roleLabel(r)),
                                  backgroundColor: AppTheme.lightBlue,
                                  labelStyle: const TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Información Personal Registrada (Minimización LOPDP)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Datos de Identificación y Contacto',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                        const Divider(height: 20),
                        _buildInfoTile(
                          Icons.email_outlined,
                          'Correo Electrónico',
                          user?.email ?? 'No registrado',
                        ),
                        _buildInfoTile(
                          Icons.phone_android_outlined,
                          'Celular',
                          user?.phoneNumber ?? 'No registrado',
                        ),
                        if (user?.birthDate != null)
                          _buildInfoTile(
                            Icons.cake_outlined,
                            'Fecha de Nacimiento',
                            DateFormat('dd/MM/yyyy').format(user!.birthDate!),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Acciones de Seguridad
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Seguridad de la Cuenta',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/change-password'),
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Actualizar Contraseña'),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorRed,
                          ),
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/login');
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Cerrar Sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 22),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
