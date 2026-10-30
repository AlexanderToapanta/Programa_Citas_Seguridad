import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCardController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime? _selectedBirthDate;

  @override
  void dispose() {
    _idCardController.dispose();
    _fullNameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Validación local del algoritmo de cédula ecuatoriana (Módulo 10)
  bool _isValidEcuadorianIdCard(String idCard) {
    if (idCard.length != 10 || !RegExp(r'^\d{10}$').hasMatch(idCard)) {
      return false;
    }
    final province = int.tryParse(idCard.substring(0, 2)) ?? 0;
    if ((province < 1 || province > 24) && province != 30) {
      return false;
    }
    final thirdDigit = int.tryParse(idCard.substring(2, 3)) ?? -1;
    if (thirdDigit < 0 || thirdDigit > 5) {
      return false; // Personas naturales
    }
    const coefficients = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      int val = (int.tryParse(idCard[i]) ?? 0) * coefficients[i];
      if (val >= 10) val -= 9;
      sum += val;
    }
    final verifier = int.tryParse(idCard[9]) ?? -1;
    final nextTen = ((sum + 9) ~/ 10) * 10;
    int computed = nextTen - sum;
    if (computed == 10) computed = 0;
    return computed == verifier;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    // Rango permitido: entre 7 días de vida (mínimo 1 semana) y 100 años
    final maxBirthDate = now.subtract(const Duration(days: 7));
    final minBirthDate = DateTime(now.year - 100, now.month, now.day);
    final initial = _selectedBirthDate != null
        ? (_selectedBirthDate!.isAfter(maxBirthDate) ? maxBirthDate : (_selectedBirthDate!.isBefore(minBirthDate) ? minBirthDate : _selectedBirthDate!))
        : DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minBirthDate,
      lastDate: maxBirthDate,
      locale: const Locale('es'),
      helpText: 'Seleccionar fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .register(
          idCard: _idCardController.text,
          fullName: _fullNameController.text,
          birthDate: _birthDateController.text,
          email: _emailController.text,
          phoneNumber: _phoneController.text,
        );

    if (success && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successGreen),
              SizedBox(width: 8),
              Text('Registro Exitoso'),
            ],
          ),
          content: Text(
            ref.read(authProvider).temporaryPasswordNotice ??
                'Se ha generado una contraseña temporal con vigencia de 15 minutos.',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/login');
              },
              child: const Text('Ir al Inicio de Sesión'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Afiliado')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Crear Cuenta de Afiliado',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Minimización de datos (LOPDP): Solo se solicitan los datos indispensables para gestionar sus turnos médicos.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Mensaje de Error del Servidor mostrado en la misma pantalla
                      if (authState.errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authState.errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Cédula
                      TextFormField(
                        controller: _idCardController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Cédula de Identidad (10 dígitos)',
                          hintText: 'Ej. 1703970622',
                          prefixIcon: Icon(Icons.badge_outlined),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length != 10) {
                            return 'Ingrese una cédula válida';
                          }
                          if (!_isValidEcuadorianIdCard(value.trim())) {
                            return 'Ingrese una cédula válida';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Nombres y Apellidos
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombres y Apellidos Completos',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 4) {
                            return 'Ingrese sus nombres y apellidos completos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Fecha de Nacimiento con Calendario
                      TextFormField(
                        controller: _birthDateController,
                        readOnly: true,
                        onTap: _pickBirthDate,
                        decoration: InputDecoration(
                          labelText: 'Fecha de Nacimiento',
                          hintText: 'Seleccione su fecha en el calendario',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.date_range, color: AppTheme.primaryBlue),
                            onPressed: _pickBirthDate,
                            tooltip: 'Abrir calendario',
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Seleccione su fecha de nacimiento';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Correo Electrónico
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico de Contacto',
                          hintText: 'ejemplo@correo.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Ingrese un correo electrónico válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Celular
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Número Celular (09...)',
                          hintText: '0981234567',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null ||
                              !value.trim().startsWith('09') ||
                              value.trim().length != 10) {
                            return 'Debe ser un celular ecuatoriano válido de 10 dígitos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: authState.isLoading ? null : _submit,
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Completar Registro'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
