import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/auth/views/change_password_screen.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/appointments/views/book_appointment_screen.dart';
import '../../features/appointments/views/my_appointments_screen.dart';
import '../../features/appointments/views/reception_appointments_screen.dart';
import '../../features/representatives/views/representatives_screen.dart';
import '../../features/admin/views/admin_screen.dart';
import '../../features/profile/views/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isAuth        = authState.isAuthenticated;
      final loc           = state.matchedLocation;
      final isLoggingIn   = loc == '/login';
      final isRegistering = loc == '/register';

      // ── Sin autenticación ──────────────────────────────────────────────────
      if (!isAuth) {
        return (isLoggingIn || isRegistering) ? null : '/login';
      }

      // ── Primer acceso: cambio obligatorio de contraseña (RF05) ─────────────
      if (authState.user?.mustChangePassword == true) {
        return loc == '/change-password' ? null : '/change-password';
      }

      // ── Redirigir login/registro al dashboard ──────────────────────────────
      if (isLoggingIn || isRegistering) return '/dashboard';

      final user = authState.user;

      // ── Protección de rutas por rol (RBAC – RF06) ──────────────────────────

      // Panel Administrativo: solo ADMIN
      if (loc == '/admin') {
        if (user?.isAdmin != true) return '/dashboard';
      }

      // Pantalla de Soporte (logs): solo SUPPORT
      if (loc == '/support') {
        if (user?.isSupport != true) return '/dashboard';
      }

      // Citas de Recepción: solo RECEPTIONIST
      if (loc == '/reception-appointments') {
        if (user?.isReceptionist != true) return '/dashboard';
      }

      // Reservar cita / mis citas / familiares: solo Afiliado y Representante
      if (loc == '/book-appointment' ||
          loc == '/my-appointments' ||
          loc == '/representatives') {
        final esAfiliado = user?.isAffiliate == true ||
            (user?.roles.contains('REPRESENTATIVE') ?? false);
        if (!esAfiliado) return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),

      // ── Rutas de Afiliado / Representante ─────────────────────────────────
      GoRoute(
        path: '/book-appointment',
        builder: (context, state) => const BookAppointmentScreen(),
      ),
      GoRoute(
        path: '/my-appointments',
        builder: (context, state) => const MyAppointmentsScreen(),
      ),
      GoRoute(
        path: '/representatives',
        builder: (context, state) => const RepresentativesScreen(),
      ),

      // ── Rutas de Recepción ─────────────────────────────────────────────────
      GoRoute(
        path: '/reception-appointments',
        builder: (context, state) => const ReceptionAppointmentsScreen(),
      ),

      // ── Rutas de Administración ────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),

      // ── Rutas de Soporte ───────────────────────────────────────────────────
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),

      // ── Perfil (compartido para todos los roles) ───────────────────────────
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
