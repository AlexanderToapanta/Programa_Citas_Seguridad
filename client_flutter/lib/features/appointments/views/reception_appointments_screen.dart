import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import 'package:iess_turnos_app/core/constants/api_constants.dart';
import 'package:iess_turnos_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:iess_turnos_app/shared/models/models.dart';

// ──────────────────────────────────────────────────────────────────────────────
// PANTALLA DE RECEPCIÓN – Ver todas las citas y cambiar fecha
// ──────────────────────────────────────────────────────────────────────────────

class ReceptionAppointmentsScreen extends ConsumerStatefulWidget {
  const ReceptionAppointmentsScreen({super.key});

  @override
  ConsumerState<ReceptionAppointmentsScreen> createState() =>
      _ReceptionAppointmentsScreenState();
}

class _ReceptionAppointmentsScreenState
    extends ConsumerState<ReceptionAppointmentsScreen> {
  bool _isLoading = false;
  List<AppointmentModel> _appointments = [];
  DateTime _selectedDate = DateTime.now();
  String _filterStatus = 'TODAS';

  static const _statusOpciones = [
    'TODAS',
    'PROGRAMADA',
    'REPROGRAMADA',
    'CANCELADA',
    'COMPLETADA',
  ];

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

  static String _statusCode(String label) {
    switch (label) {
      case 'PROGRAMADA':   return 'SCHEDULED';
      case 'REPROGRAMADA': return 'RESCHEDULED';
      case 'CANCELADA':    return 'CANCELLED';
      case 'COMPLETADA':   return 'COMPLETED';
      default:             return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final res = await client.dio.get(
        ApiConstants.myAppointments,
        queryParameters: {'date': dateStr},
      );
      setState(() {
        _appointments = (res.data as List)
            .map((e) => AppointmentModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        _appointments.sort(
            (a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<AppointmentModel> get _filteredAppointments {
    if (_filterStatus == 'TODAS') return _appointments;
    final code = _statusCode(_filterStatus);
    return _appointments.where((a) => a.status == code).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      locale: const Locale('es'),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadAppointments();
    }
  }

  void _onRescheduleDate(AppointmentModel appt) async {
    // Solo recepción puede cambiar de día directamente
    final picked = await showDatePicker(
      context: context,
      initialDate: appt.scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      locale: const Locale('es'),
      helpText: 'Seleccionar nuevo día',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null || !mounted) return;

    // Obtener slots disponibles en ese día para la misma especialidad
    try {
      final client = ref.read(apiClientProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      final res = await client.dio.get(
        ApiConstants.availabilitySlots,
        queryParameters: {'date': dateStr},
      );

      if (!mounted) return;

      final slots = (res.data as List)
          .map((e) =>
              SlotModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (slots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No hay horarios disponibles para la fecha seleccionada.'),
          ),
        );
        return;
      }

      final selectedSlotId = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Seleccionar Nuevo Horario'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: slots.length,
              itemBuilder: (c, i) {
                final s = slots[i];
                return ListTile(
                  title: Text('${s.specialtyName} – ${s.doctorName}'),
                  subtitle: Text(
                    DateFormat('HH:mm', 'es').format(s.startTime),
                  ),
                  trailing:
                      const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(ctx).pop(s.id),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (selectedSlotId == null || !mounted) return;

      await client.dio.patch(
        '${ApiConstants.appointments}/${appt.id}/reschedule',
        data: {'newSlotId': selectedSlotId},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita reprogramada exitosamente.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        await _loadAppointments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reprogramar: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredAppointments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Citas – Recepción'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadAppointments,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        child: CustomScrollView(
          slivers: [
            // ── Selector de fecha ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Botón de selección de fecha
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.primaryBlue.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(10),
                          color: AppTheme.lightBlue,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: AppTheme.primaryBlue, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('EEEE d MMMM yyyy', 'es')
                                  .format(_selectedDate),
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down,
                                color: AppTheme.primaryBlue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filtros por estado
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusOpciones.map((op) {
                          final selected = _filterStatus == op;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(op),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _filterStatus = op),
                              selectedColor:
                                  AppTheme.primaryBlue.withOpacity(0.15),
                              checkmarkColor: AppTheme.primaryBlue,
                              labelStyle: TextStyle(
                                color: selected
                                    ? AppTheme.primaryBlue
                                    : AppTheme.textDark,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Contador
                    Text(
                      '${displayed.length} cita(s) encontrada(s)',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),

            // ── Lista de citas ─────────────────────────────────────────────
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (displayed.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No hay citas para la fecha y filtro seleccionados.',
                      style: TextStyle(color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i < displayed.length) {
                        return _buildAppointmentCard(displayed[i]);
                      }
                      if (i == displayed.length) {
                        return const SizedBox(height: 24);
                      }
                      return null;
                    },
                    childCount: displayed.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appt) {
    final canReschedule = appt.isActive &&
        appt.scheduledAt.difference(DateTime.now()).inHours >= 0;

    Color statusBg = AppTheme.lightBlue;
    Color statusFg = AppTheme.primaryBlue;
    if (appt.status == 'CANCELLED') {
      statusBg = Colors.red.shade50;
      statusFg = AppTheme.errorRed;
    } else if (appt.status == 'COMPLETED') {
      statusBg = Colors.green.shade50;
      statusFg = AppTheme.successGreen;
    } else if (appt.status == 'NO_SHOW') {
      statusBg = Colors.orange.shade50;
      statusFg = AppTheme.warningOrange;
    } else if (appt.status == 'RESCHEDULED') {
      statusBg = Colors.purple.shade50;
      statusFg = Colors.purple.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Chip(
                  label: Text(_statusLabel(appt.status)),
                  backgroundColor: statusBg,
                  labelStyle: TextStyle(
                    color: statusFg,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _infoRow(Icons.person,
                'Paciente: ${appt.affiliateName} · ${appt.affiliateIdCard}'),
            _infoRow(
              Icons.schedule,
              DateFormat('HH:mm', 'es').format(appt.scheduledAt),
            ),
            _infoRow(Icons.medical_services, 'Médico: ${appt.doctorName}'),
            _infoRow(Icons.location_on_outlined, appt.facilityName),
            if (appt.isActive) ...[
              const Divider(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed:
                      canReschedule ? () => _onRescheduleDate(appt) : null,
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: const Text('Cambiar Día / Horario'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textDark)),
          ),
        ],
      ),
    );
  }
}

