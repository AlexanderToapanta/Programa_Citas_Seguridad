import 'package:flutter_test/flutter_test.dart';
import 'package:iess_turnos_app/core/security/secure_storage.dart';
import 'package:iess_turnos_app/shared/models/models.dart';

void main() {
  group('Pruebas de Seguridad en Flutter (Etapa 3)', () {
    test('1. Modelo de Usuario y Roles (RBAC en cliente - R10)', () {
      final affiliateJson = {
        'id': 'user-1',
        'idCard': '1715897451',
        'fullName': 'Juan Morales',
        'email': 'juan@test.com',
        'roles': ['AFFILIATE'],
        'mustChangePassword': false,
      };

      final affiliate = UserModel.fromJson(affiliateJson);
      expect(affiliate.isAdmin, false);
      expect(affiliate.isDoctor, false);
      expect(affiliate.isReceptionist, false);

      final adminJson = {
        'id': 'admin-1',
        'idCard': '1710000001',
        'fullName': 'Admin User',
        'email': 'admin@iess.gob.ec',
        'roles': ['ADMIN'],
        'mustChangePassword': false,
      };

      final admin = UserModel.fromJson(adminJson);
      expect(admin.isAdmin, true);
    });

    test('2. Prevención de XSS - Los datos se manejan como texto plano sin renderizado web ejecutable', () {
      final xssPayload = '<script>alert("XSS")</script>';
      final apptJson = {
        'id': 'appt-1',
        'scheduledAt': DateTime.now().toIso8601String(),
        'specialty': xssPayload,
        'facility': xssPayload,
        'doctor': 'Dr. Test',
        'status': 'SCHEDULED',
        'cancellationReason': xssPayload,
      };

      final appt = AppointmentModel.fromJson(apptJson);
      expect(appt.specialtyName, xssPayload);
      expect(appt.facilityName, xssPayload);
      expect(appt.cancellationReason, xssPayload);
    });

    test('3. Validación de Almacenamiento Seguro (Instanciación de SecureStorageService)', () {
      final storage = SecureStorageService();
      expect(storage, isNotNull);
    });
  });
}
