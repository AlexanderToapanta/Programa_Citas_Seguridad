import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:iess_turnos_app/core/network/api_client.dart';
import 'package:iess_turnos_app/core/security/secure_storage.dart';
import 'package:iess_turnos_app/shared/models/models.dart';
import 'package:iess_turnos_app/core/constants/api_constants.dart';

// ==========================================
// PROVIDER DE ALMACENAMIENTO SEGURO
// ==========================================

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// ==========================================
// PROVIDER DEL CLIENTE API
// ==========================================

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);

  return ApiClient(storageService: storage);
});

// ==========================================
// ESTADO DE AUTENTICACIÓN
// ==========================================

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? errorMessage;
  final String? temporaryPasswordNotice;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
    this.temporaryPasswordNotice,
  });

  // Crear una copia actualizada del estado
  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    bool clearUser = false,
    String? errorMessage,
    String? temporaryPasswordNotice,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: errorMessage,
      temporaryPasswordNotice: temporaryPasswordNotice,
    );
  }
}

// ==========================================
// VIEWMODEL DE AUTENTICACIÓN
// ==========================================

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  AuthNotifier(this._apiClient, this._storage)
    : super(const AuthState(isLoading: true)) {
    _restoreSession();
  }

  // ==========================================
  // 1. RESTAURAR SESIÓN
  // ==========================================

  Future<void> _restoreSession() async {
    try {
      final token = await _storage.getToken();
      final userJson = await _storage.getUserJson();

      if (!mounted) return;

      if (token != null &&
          token.isNotEmpty &&
          userJson != null &&
          userJson.isNotEmpty) {
        final user = UserModel.fromRawJson(userJson);

        // Comprobar que el token continúa siendo válido
        // mediante un endpoint autenticado.
        try {
          await _apiClient.dio.get(ApiConstants.myAppointments);

          if (!mounted) return;

          state = AuthState(
            isAuthenticated: true,
            user: user,
            isLoading: false,
          );

          return;
        } catch (_) {
          // El token podría haber expirado o la red
          // podría estar temporalmente inaccesible.
          // Por seguridad, no se restaura la sesión.
          await _storage.clearAll();
        }
      } else {
        await _storage.clearAll();
      }
    } catch (_) {
      try {
        await _storage.clearAll();
      } catch (_) {
        // Evitar errores adicionales durante la limpieza
      }
    }

    if (!mounted) return;

    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  // ==========================================
  // 2. INICIAR SESIÓN
  // ==========================================

  Future<bool> login(String idCard, String password) async {
    if (idCard.trim().isEmpty || password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Ingrese su cédula y contraseña',
      );

      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      temporaryPasswordNotice: null,
    );

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.login,
        data: {'idCard': idCard.trim(), 'password': password},
      );

      final responseData = Map<String, dynamic>.from(response.data as Map);

      final token = responseData['accessToken'] as String;

      if (token.isEmpty) {
        throw const FormatException('El servidor no devolvió un token válido');
      }

      final userData = Map<String, dynamic>.from(responseData['user'] as Map);

      final mustChange = responseData['mustChangePassword'] as bool? ?? false;

      final user = UserModel.fromJson({
        ...userData,
        'mustChangePassword': mustChange,
      });

      await _storage.saveToken(token);
      await _storage.saveUserJson(user.toRawJson());

      if (!mounted) return false;

      state = AuthState(isLoading: false, isAuthenticated: true, user: user);

      return true;
    } catch (e) {
      final message = _apiClient.extractErrorMessage(e);

      // Limpiar posibles credenciales parciales
      try {
        await _storage.clearAll();
      } catch (_) {}

      if (!mounted) return false;

      state = AuthState(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: message,
      );

      return false;
    }
  }

  // ==========================================
  // 3. REGISTRAR USUARIO
  // ==========================================

  Future<bool> register({
    required String idCard,
    required String fullName,
    required String birthDate,
    required String email,
    required String phoneNumber,
  }) async {
    if (idCard.trim().isEmpty ||
        fullName.trim().isEmpty ||
        birthDate.trim().isEmpty ||
        email.trim().isEmpty ||
        phoneNumber.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Todos los campos son obligatorios',
      );

      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      temporaryPasswordNotice: null,
    );

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.register,
        data: {
          'idCard': idCard.trim(),
          'fullName': fullName.trim(),
          'birthDate': birthDate.trim(),
          'email': email.trim(),
          'phoneNumber': phoneNumber.trim(),
        },
      );

      final responseData = Map<String, dynamic>.from(response.data as Map);

      final tempCred = responseData['temporaryCredential'];

      String? tempPwd;

      if (tempCred is Map) {
        tempPwd = tempCred['temporaryPassword']?.toString();
      }

      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        temporaryPasswordNotice: tempPwd != null
            ? 'Su contraseña temporal asignada es:\n\n' + tempPwd + '\n\n(Tiene 15 minutos de vigencia. Al ingresar se le pedirá cambiarla obligatoriamente).'
            : 'Registro completado correctamente. Revise su correo electrónico para obtener las instrucciones de acceso.',
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        errorMessage: _apiClient.extractErrorMessage(e),
        temporaryPasswordNotice: null,
      );

      return false;
    }
  }

  // ==========================================
  // 4. CAMBIAR CONTRASEÑA
  // ==========================================

  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Ingrese la contraseña actual y la nueva',
      );

      return false;
    }

    if (newPassword.length < 8) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'La nueva contraseña debe tener '
            'al menos 8 caracteres',
      );

      return false;
    }

    if (currentPassword == newPassword) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'La nueva contraseña debe ser diferente '
            'a la contraseña actual',
      );

      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      temporaryPasswordNotice: null,
    );

    try {
      await _apiClient.dio.post(
        ApiConstants.changePassword,
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );

      if (!mounted) return false;

      UserModel? updatedUser;

      if (state.user != null) {
        final currentUser = state.user!;

        updatedUser = UserModel(
          id: currentUser.id,
          idCard: currentUser.idCard,
          fullName: currentUser.fullName,
          email: currentUser.email,
          phoneNumber: currentUser.phoneNumber,
          birthDate: currentUser.birthDate,
          roles: currentUser.roles,
          mustChangePassword: false,
        );

        await _storage.saveUserJson(updatedUser.toRawJson());
      }

      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        user: updatedUser,
        errorMessage: null,
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        errorMessage: _apiClient.extractErrorMessage(e),
      );

      return false;
    }
  }

  // ==========================================
  // 5. CERRAR SESIÓN
  // ==========================================

  Future<void> logout() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      temporaryPasswordNotice: null,
    );

    try {
      await _apiClient.dio.post(ApiConstants.logout);
    } catch (_) {
      // Aunque falle el servidor,
      // se intenta cerrar sesión localmente.
    }

    try {
      await _storage.clearAll();
    } catch (_) {
      // El almacenamiento podría no estar disponible.
    }

    if (!mounted) return;

    state = const AuthState(
      isLoading: false,
      isAuthenticated: false,
      user: null,
    );
  }

  // ==========================================
  // 6. LIMPIAR MENSAJES
  // ==========================================

  void clearMessages() {
    state = state.copyWith(errorMessage: null, temporaryPasswordNotice: null);
  }

  // ==========================================
  // 7. OBTENER USUARIO ACTUAL
  // ==========================================

  UserModel? get currentUser {
    return state.user;
  }

  // ==========================================
  // 8. COMPROBAR AUTENTICACIÓN
  // ==========================================

  bool get isLoggedIn {
    return state.isAuthenticated && state.user != null;
  }
}

// ==========================================
// PROVIDER DE AUTENTICACIÓN
// ==========================================

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);

  final storage = ref.watch(secureStorageProvider);

  return AuthNotifier(api, storage);
});
