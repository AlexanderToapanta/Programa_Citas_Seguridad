import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import 'package:iess_turnos_app/shared/models/models.dart';
import 'package:iess_turnos_app/features/appointments/viewmodels/appointments_viewmodel.dart';

class MyAppointmentsScreen extends ConsumerStatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  ConsumerState<MyAppointmentsScreen> createState() =>
      _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends ConsumerState<MyAppointmentsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(appointmentsProvider.notifier).fetchMyAppointments();
    });
  }

  void _onCancel(AppointmentModel appt) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Cita Médica'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Está seguro de cancelar su turno de ${appt.specialtyName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo de la cancelación',
                hintText: 'Ej. Imprevisto familiar o laboral',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, mantener cita'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, Cancelar Cita'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final reason = reasonController.text.trim().isEmpty
          ? 'Cancelación voluntaria'
          : reasonController.text.trim();
      final success = await ref
          .read(appointmentsProvider.notifier)
          .cancelAppointment(appt.id, reason);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita cancelada y cupo liberado en el sistema.'),
          ),
        );
      }
    }
  }

  void _onReschedule(AppointmentModel appt) async {
    // Regla de 8 horas: comprobar en el cliente para UX accesible
    final diffHours = appt.scheduledAt.difference(DateTime.now()).inHours;
    if (diffHours < 8) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Plazo Excedido (RF01)'),
          content: const Text(
            'Las citas médicas solo pueden reprogramarse con al menos 8 horas de anticipación a su inicio.\n\nPara casos excepcionales, por favor acuda a la recepción del establecimiento.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // Buscar cupos disponibles para reprogramar
    await ref.read(appointmentsProvider.notifier).searchSlots();
    final slots = ref.read(appointmentsProvider).availableSlots;

    if (!mounted) return;

    final selectedSlotId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar Nuevo Horario'),
        content: SizedBox(
          width: double.maxFinite,
          child: slots.isEmpty
              ? const Text('No hay otros cupos disponibles en este momento.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: slots.length,
                  itemBuilder: (c, i) {
                    final s = slots[i];
                    return ListTile(
                      title: Text('${s.specialtyName} - ${s.doctorName}'),
                      subtitle: Text(
                        DateFormat(
                          'EEEE d MMMM, HH:mm',
                          'es',
                        ).format(s.startTime),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => Navigator.of(ctx).pop(s.id),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    if (selectedSlotId != null && mounted) {
      final success = await ref
          .read(appointmentsProvider.notifier)
          .rescheduleAppointment(appt.id, selectedSlotId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita reprogramada exitosamente.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Citas Médicas')),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(appointmentsProvider.notifier).fetchMyAppointments(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: AppTheme.errorRed),
                      ),
                    ),

                  if (state.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (state.myAppointments.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No tiene citas registradas en su historial.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.myAppointments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final appt = state.myAppointments[idx];
                        final canCancel =
                            appt.isActive &&
                            appt.scheduledAt.isAfter(DateTime.now());
                        final canReschedule =
                            appt.isActive &&
                            appt.scheduledAt
                                    .difference(DateTime.now())
                                    .inHours >=
                                8;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        appt.specialtyName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    _buildStatusChip(appt.status),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Afiliado: ${appt.affiliateName} (${appt.affiliateIdCard.isNotEmpty ? appt.affiliateIdCard : "Titular"})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  'Fecha: ${DateFormat('EEEE d MMMM yyyy, HH:mm', 'es').format(appt.scheduledAt)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Establecimiento: ${appt.facilityName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                Text(
                                  'Médico: ${appt.doctorName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                if (appt.cancellationReason != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Motivo: ${appt.cancellationReason}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.errorRed,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                if (appt.isActive) ...[
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: canReschedule
                                            ? () => _onReschedule(appt)
                                            : null,
                                        icon: const Icon(
                                          Icons.edit_calendar,
                                          size: 16,
                                        ),
                                        label: const Text('Reprogramar'),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.errorRed,
                                          minimumSize: const Size(110, 40),
                                        ),
                                        onPressed: canCancel
                                            ? () => _onCancel(appt)
                                            : null,
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          size: 16,
                                        ),
                                        label: const Text('Cancelar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'SCHEDULED':    return 'Programada';
      case 'RESCHEDULED':  return 'Reprogramada';
      case 'CANCELLED':    return 'Cancelada';
      case 'COMPLETED':    return 'Completada';
      case 'NO_SHOW':      return 'Inasistencia';
      default:             return status;
    }
  }

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
