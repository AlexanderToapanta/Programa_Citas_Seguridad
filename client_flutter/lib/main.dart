import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar datos de localización para el paquete intl (requerido en Flutter Web)
  await initializeDateFormatting('es', null);
  runApp(const ProviderScope(child: IessTurnosApp()));
}

class IessTurnosApp extends ConsumerWidget {
  const IessTurnosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'IESS - Sistema de Turnos Médicos (Prototipo)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
