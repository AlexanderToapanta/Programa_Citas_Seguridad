import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import 'package:iess_turnos_app/shared/models/models.dart';
import 'package:iess_turnos_app/features/appointments/viewmodels/appointments_viewmodel.dart';
import 'package:iess_turnos_app/features/auth/viewmodels/auth_viewmodel.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  String? _selectedSpecialtyId;
  String? _selectedFacilityId;
  DateTime? _selectedDate;
  final _beneficiaryCardController = TextEditingController();
  bool _isBookingForRelative = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(appointmentsProvider.notifier).fetchCatalogs();
      _onSearch();
    });
  }

  @override
  void dispose() {
    _beneficiaryCardController.dispose();
    super.dispose();
  }

  void _onSearch() {
    ref
        .read(appointmentsProvider.notifier)
        .searchSlots(
          specialtyId: _selectedSpecialtyId,
          facilityId: _selectedFacilityId,
          date: _selectedDate != null
              ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
              : null,
        );
  }

  void _confirmBooking(SlotModel slot) async {
    final specialty = ref
        .read(appointmentsProvider)
        .specialties
        .firstWhere(
          (s) => s.id == slot.specialtyCode || s.name == slot.specialtyName,
          orElse: () => SpecialtyModel(
            id: '',
            code: '',
            name: slot.specialtyName,
            description: '',
            requiresReferral: slot.requiresReferral,
          ),
        );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Reserva de Turno'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Especialidad: ${slot.specialtyName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Establecimiento: ${slot.facilityName} (${slot.facilityCity})',
            ),
            Text('Médico: ${slot.doctorName}'),
            Text(
              'Horario: ${DateFormat('EEEE d \'de\' MMMM, HH:mm', 'es_ES').format(slot.startTime)}',
            ),
            if (slot.requiresReferral) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.warningOrange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta especialidad requiere derivación médica previa. El sistema validará su registro en el IESS.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isBookingForRelative) ...[
              const SizedBox(height: 10),
              Text(
                'Beneficiario: Cédula ${_beneficiaryCardController.text.trim()}',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar Turno'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref
          .read(appointmentsProvider.notifier)
          .bookAppointment(
            slotId: slot.id,
            affiliateIdCard: _isBookingForRelative
                ? _beneficiaryCardController.text.trim()
                : null,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cita médica confirmada con éxito!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        context.go('/my-appointments');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reservar Cita Médica')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filtros de búsqueda
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Paso 1: Seleccione Criterios de Atención',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                        const SizedBox(height: 16),

                        // Opción de agendar para un familiar autorizado (RF04)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Agendar cita para un familiar autorizado',
                          ),
                          subtitle: const Text(
                            'Requiere contar con una autorización familiar válida',
                          ),
                          value: _isBookingForRelative,
                          onChanged: (val) {
                            setState(() {
                              _isBookingForRelative = val;
                            });
                          },
                        ),
                        if (_isBookingForRelative) ...[
                          TextFormField(
                            controller: _beneficiaryCardController,
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: 'Cédula del Familiar Beneficiario',
                              prefixIcon: Icon(Icons.badge_outlined),
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Filtro de Especialidad
                        DropdownButtonFormField<String>(
                          value: _selectedSpecialtyId,
                          decoration: const InputDecoration(
                            labelText: 'Especialidad Médica',
                            prefixIcon: Icon(Icons.medical_services_outlined),
                          ),
                          hint: const Text('Todas las especialidades'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todas las especialidades'),
                            ),
                            ...state.specialties.map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  '${s.name} ${s.requiresReferral ? "(Req. Derivación)" : ""}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedSpecialtyId = val);
                            _onSearch();
                          },
                        ),
                        const SizedBox(height: 14),

                        // Filtro de Establecimiento
                        DropdownButtonFormField<String>(
                          value: _selectedFacilityId,
                          decoration: const InputDecoration(
                            labelText: 'Establecimiento de Salud',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          hint: const Text('Todos los establecimientos'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos los establecimientos'),
                            ),
                            ...state.facilities.map(
                              (f) => DropdownMenuItem(
                                value: f.id,
                                child: Text(
                                  '${f.name} - ${f.city}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedFacilityId = val);
                            _onSearch();
                          },
                        ),
                        const SizedBox(height: 14),

                        // Selector de Fecha
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? now,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 30)),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                              _onSearch();
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _selectedDate == null
                                ? 'Cualquier fecha disponible'
                                : 'Fecha: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Mensajes de Alerta / Error
                if (state.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.errorRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.errorRed,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Lista de Cupos Disponibles
                Text(
                  'Paso 2: Cupos y Horarios Disponibles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                if (state.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.availableSlots.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No se encontraron cupos con los filtros seleccionados. Intente con otra fecha o especialidad.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.availableSlots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final slot = state.availableSlots[idx];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat(
                                        'HH:mm',
                                      ).format(slot.startTime),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'dd/MM',
                                      ).format(slot.startTime),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slot.specialtyName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${slot.facilityName} (${slot.facilityCity})',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      'Médico: ${slot.doctorName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _confirmBooking(slot),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(100, 42),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                                child: const Text('Reservar'),
                              ),
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
    );
  }
}
