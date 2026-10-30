import 'package:flutter_riverpod/legacy.dart';

import 'package:iess_turnos_app/core/network/api_client.dart';
import 'package:iess_turnos_app/shared/models/models.dart';
import 'package:iess_turnos_app/core/constants/api_constants.dart';
import 'package:iess_turnos_app/features/auth/viewmodels/auth_viewmodel.dart';

// ==========================================
// ESTADO DE LAS CITAS MÉDICAS
// ==========================================

class AppointmentsState {
  final bool isLoading;
  final List<AppointmentModel> myAppointments;
  final List<SpecialtyModel> specialties;
  final List<FacilityModel> facilities;
  final List<SlotModel> availableSlots;
  final String? errorMessage;
  final String? successMessage;

  AppointmentsState({
    this.isLoading = false,
    this.myAppointments = const [],
    this.specialties = const [],
    this.facilities = const [],
    this.availableSlots = const [],
    this.errorMessage,
    this.successMessage,
  });

  // Obtener la próxima cita médica activa
  AppointmentModel? get nextAppointment {
    final now = DateTime.now();

    final active = myAppointments
        .where(
          (appointment) =>
              appointment.isActive && appointment.scheduledAt.isAfter(now),
        )
        .toList();

    if (active.isEmpty) {
      return null;
    }

    active.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return active.first;
  }

  // Crear una copia actualizada del estado
  AppointmentsState copyWith({
    bool? isLoading,
    List<AppointmentModel>? myAppointments,
    List<SpecialtyModel>? specialties,
    List<FacilityModel>? facilities,
    List<SlotModel>? availableSlots,
    String? errorMessage,
    String? successMessage,
  }) {
    return AppointmentsState(
      isLoading: isLoading ?? this.isLoading,
      myAppointments: myAppointments ?? this.myAppointments,
      specialties: specialties ?? this.specialties,
      facilities: facilities ?? this.facilities,
      availableSlots: availableSlots ?? this.availableSlots,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

// ==========================================
// VIEWMODEL DE CITAS MÉDICAS
// ==========================================

class AppointmentsNotifier extends StateNotifier<AppointmentsState> {
  final ApiClient _apiClient;

  AppointmentsNotifier(this._apiClient) : super(AppointmentsState());

  // ==========================================
  // 1. OBTENER CATÁLOGOS
  // ==========================================

  Future<void> fetchCatalogs() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      final specRes = await _apiClient.dio.get(ApiConstants.specialties);

      final facRes = await _apiClient.dio.get(ApiConstants.facilities);

      final specialties = (specRes.data as List)
          .map(
            (e) => SpecialtyModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      final facilities = (facRes.data as List)
          .map(
            (e) => FacilityModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        specialties: specialties,
        facilities: facilities,
        errorMessage: null,
      );
    } catch (e) {
      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        errorMessage: _apiClient.extractErrorMessage(e),
      );
    }
  }

  // ==========================================
  // 2. OBTENER MIS CITAS MÉDICAS
  // ==========================================

  Future<void> fetchMyAppointments() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await _apiClient.dio.get(ApiConstants.myAppointments);

      final appointments = (res.data as List)
          .map(
            (e) =>
                AppointmentModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      appointments.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        myAppointments: appointments,
        errorMessage: null,
      );
    } catch (e) {
      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        errorMessage: _apiClient.extractErrorMessage(e),
      );
    }
  }

  // ==========================================
  // 3. BUSCAR HORARIOS DISPONIBLES
  // ==========================================

  Future<void> searchSlots({
    String? specialtyId,
    String? facilityId,
    String? date,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
      availableSlots: [],
    );

    try {
      final queryParams = <String, dynamic>{};

      if (specialtyId != null && specialtyId.isNotEmpty) {
        queryParams['specialtyId'] = specialtyId;
      }

      if (facilityId != null && facilityId.isNotEmpty) {
        queryParams['facilityId'] = facilityId;
      }

      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }

      final res = await _apiClient.dio.get(
        ApiConstants.availabilitySlots,
        queryParameters: queryParams,
      );

      final slots = (res.data as List)
          .map((e) => SlotModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        availableSlots: slots,
        errorMessage: null,
      );
    } catch (e) {
      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        availableSlots: [],
        errorMessage: _apiClient.extractErrorMessage(e),
      );
    }
  }

  // ==========================================
  // 4. AGENDAR UNA CITA MÉDICA
  // ==========================================

  Future<bool> bookAppointment({
    required String slotId,
    String? affiliateIdCard,
  }) async {
    if (slotId.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Debe seleccionar un horario válido',
        successMessage: null,
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      final data = <String, dynamic>{'slotId': slotId};

      if (affiliateIdCard != null && affiliateIdCard.trim().isNotEmpty) {
        data['affiliateIdCard'] = affiliateIdCard.trim();
      }

      await _apiClient.dio.post(ApiConstants.appointments, data: data);

      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Cita médica agendada exitosamente',
        errorMessage: null,
      );

      // Actualizar las citas después de agendar
      await fetchMyAppointments();

      return true;
    } catch (e) {
      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        errorMessage: _apiClient.extractErrorMessage(e),
        successMessage: null,
      );

      return false;
    }
  }

  // ==========================================
  // 5. REPROGRAMAR UNA CITA MÉDICA
  // ==========================================

  Future<bool> rescheduleAppointment(
    String appointmentId,
    String newSlotId,
  ) async {
    if (appointmentId.trim().isEmpty || newSlotId.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Debe seleccionar una cita y un horario válido',
        successMessage: null,
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      await _apiClient.dio.patch(
        '${ApiConstants.appointments}/$appointmentId/reschedule',
        data: {'newSlotId': newSlotId},
      );

      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Cita reprogramada con éxito',
        errorMessage: null,
      );

      // Actualizar las citas
      await fetchMyAppointments();

      return true;
    } catch (e) {
      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        errorMessage: _apiClient.extractErrorMessage(e),
        successMessage: null,
      );

      return false;
    }
  }

  // ==========================================
  // 6. CANCELAR UNA CITA MÉDICA
  // ==========================================

  Future<bool> cancelAppointment(String appointmentId, String reason) async {
    if (appointmentId.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Identificador de cita inválido',
        successMessage: null,
      );
      return false;
    }

    if (reason.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Debe ingresar un motivo de cancelación',
        successMessage: null,
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      await _apiClient.dio.patch(
        '${ApiConstants.appointments}/$appointmentId/cancel',
        data: {'reason': reason.trim()},
      );

      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Cita cancelada correctamente',
        errorMessage: null,
      );

      // Actualizar las citas
      await fetchMyAppointments();

      return true;
    } catch (e) {
      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        errorMessage: _apiClient.extractErrorMessage(e),
        successMessage: null,
      );

      return false;
    }
  }

  // ==========================================
  // 7. LIMPIAR MENSAJES
  // ==========================================

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  // ==========================================
  // 8. LIMPIAR HORARIOS DISPONIBLES
  // ==========================================

  void clearAvailableSlots() {
    state = state.copyWith(
      availableSlots: [],
      errorMessage: null,
      successMessage: null,
    );
  }
}

// ==========================================
// PROVIDER DE RIVERPOD
// ==========================================

final appointmentsProvider =
    StateNotifierProvider<AppointmentsNotifier, AppointmentsState>((ref) {
      final api = ref.watch(apiClientProvider);

      return AppointmentsNotifier(api);
    });
