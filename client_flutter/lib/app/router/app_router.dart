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
import '../../features/representatives/views/representatives_screen.dart';
import '../../features/admin/views/admin_screen.dart';
import '../../features/profile/views/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isAuth = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      if (!isAuth) {
        return (isLoggingIn || isRegistering) ? null : '/login';
      }

      // Si tiene bandera de cambio obligatorio en primer acceso (RF05)
      if (authState.user?.mustChangePassword == true) {
        return state.matchedLocation == '/change-password' ? null : '/change-password';
      }

      if (isLoggingIn || isRegistering) {
        return '/dashboard';
      }

      // Control RBAC de ruta de administración (RF06)
      if (state.matchedLocation == '/admin') {
        final isAdminOrStaff = authState.user?.isAdmin == true || authState.user?.isReceptionist == true;
        if (!isAdminOrStaff) return '/dashboard';
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
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

