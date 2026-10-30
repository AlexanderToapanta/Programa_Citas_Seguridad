import 'package:flutter/foundation.dart';

class ApiConstants {
  // Prototipo académico:
  // - En Flutter Web: conecta a localhost:3000
  // - En Emulador Android: 10.0.2.2 es el alias hacia el localhost del host
  // - En dispositivo físico Android: se puede sobreescribir con --dart-define=API_URL=http://<IP>:3000
  static String get baseUrl {
    const definedUrl = String.fromEnvironment('API_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // 10.0.2.2 → emulador virtual (AVD) — alias interno hacia localhost del host
        // 192.168.18.2 → dispositivo físico Android conectado por WiFi
        // Si se conecta por emulador, usa 10.0.2.2; si es celular real, usa la IP de la PC.
        return kIsWeb ? 'http://localhost:3000' : 'http://192.168.18.2:3000';
      default:
        return 'http://localhost:3000';
    }
  }

  // Rutas de autenticación
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String changePassword = '/auth/change-password';
  static const String logout = '/auth/logout';

  // Rutas de perfil y usuarios
  static const String userProfile = '/users/me';
  static const String usersList = '/users';

  // Rutas de catálogos y disponibilidad
  static const String specialties = '/specialties';
  static const String facilities = '/facilities';
  static const String availabilitySlots = '/availability/slots';

  // Rutas de citas médicas
  static const String appointments = '/appointments';
  static const String myAppointments = '/appointments/my';

  // Rutas de familiares autorizados
  static const String representatives = '/representatives';
  static const String givenAuthorizations = '/representatives/my-authorizations';
  static const String receivedAuthorizations = '/representatives/delegated-to-me';

  // Auditoría y monitoreo
  static const String auditLogs = '/audit/logs';
  static const String health = '/health';
}

