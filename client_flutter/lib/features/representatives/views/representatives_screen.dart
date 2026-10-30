import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import 'package:iess_turnos_app/core/constants/api_constants.dart';
import 'package:iess_turnos_app/core/network/api_client.dart';
import 'package:iess_turnos_app/shared/models/models.dart';
import 'package:iess_turnos_app/features/auth/viewmodels/auth_viewmodel.dart';

class RepresentativesScreen extends ConsumerStatefulWidget {
  const RepresentativesScreen({super.key});

  @override
  ConsumerState<RepresentativesScreen> createState() =>
      _RepresentativesScreenState();
}

class _RepresentativesScreenState extends ConsumerState<RepresentativesScreen> {
  bool _isLoading = false;
  List<FamilyAuthorizationModel> _givenAuths = [];
  List<FamilyAuthorizationModel> _receivedAuths = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAuthorizations();
  }

  Future<void> _loadAuthorizations() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final resGiven = await client.dio.get(ApiConstants.givenAuthorizations);
      final resRecv = await client.dio.get(ApiConstants.receivedAuthorizations);

      final given = (resGiven.data as List)
          .map((e) => FamilyAuthorizationModel.fromJson(e))
          .toList();
      final recv = (resRecv.data as List)
          .map((e) => FamilyAuthorizationModel.fromJson(e))
          .toList();

      setState(() {
        _givenAuths = given;
        _receivedAuths = recv;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ref.read(apiClientProvider).extractErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() async {
    final cardCtrl = TextEditingController();
    final proofCtrl = TextEditingController();
    String relationship = 'HIJO';
    String method = 'OTP_CONTACTO';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Autorizar a un Familiar (RF04)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Mecanismo Verificable: Para proteger al paciente, no basta con la cédula. Se requiere validación de consentimiento (OTP/Código).',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: cardCtrl,
                  maxLength: 10,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cédula del Familiar (10 dígitos)',
                    prefixIcon: Icon(Icons.badge_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: relationship,
                  decoration: const InputDecoration(labelText: 'Parentesco'),
                  items: const [
                    DropdownMenuItem(value: 'HIJO', child: Text('Hijo / Hija')),
                    DropdownMenuItem(value: 'PADRE', child: Text('Padre')),
                    DropdownMenuItem(value: 'MADRE', child: Text('Madre')),
                    DropdownMenuItem(value: 'CONYUGE', child: Text('Cónyuge')),
                    DropdownMenuItem(
                      value: 'TUTOR_LEGAL',
                      child: Text('Tutor Legal'),
                    ),
                  ],
                  onChanged: (val) => setDState(() => relationship = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(
                    labelText: 'Método de Verificación',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'OTP_CONTACTO',
                      child: Text('Código OTP SMS/Correo'),
                    ),
                    DropdownMenuItem(
                      value: 'CODIGO_DACTILAR',
                      child: Text('Código Dactilar'),
                    ),
                    DropdownMenuItem(
                      value: 'TUTORIA_ASISTIDA',
                      child: Text('Tutoría Asistida'),
                    ),
                  ],
                  onChanged: (val) => setDState(() => method = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proofCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código / Comprobación',
                    hintText: 'Ej. 892341',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Conceder Autorización'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      try {
        final client = ref.read(apiClientProvider);
        await client.dio.post(
          ApiConstants.representatives,
          data: {
            'representativeIdCard': cardCtrl.text.trim(),
            'relationship': relationship,
            'verificationMethod': method,
            'verificationProof': proofCtrl.text.trim(),
            'validUntil': DateTime.now()
                .add(const Duration(days: 365))
                .toIso8601String()
                .split('T')
                .first,
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autorización familiar concedida exitosamente.'),
          ),
        );
        _loadAuthorizations();
      } catch (e) {
        final msg = ref.read(apiClientProvider).extractErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Familiares y Representación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Autorizar Familiar',
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAuthorizations,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppTheme.errorRed),
                            ),
                          ),

                        // Sección 1: Familiares a los que he autorizado
                        Text(
                          'Familiares Autorizados a Gestionar Mis Citas',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (_givenAuths.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                'No ha otorgado autorizaciones a ningún familiar.',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _givenAuths.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final a = _givenAuths[i];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppTheme.lightBlue,
                                    child: Icon(
                                      Icons.people,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  title: Text(
                                    a.representativeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Cédula: ${a.representativeIdCard} | Vínculo: ${a.relationship}\nVálido hasta: ${DateFormat('yyyy-MM-dd').format(a.validUntil)}',
                                  ),
                                  trailing: Chip(label: Text(a.status)),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 24),

                        // Sección 2: Afiliados que me han autorizado
                        Text(
                          'Afiliados que me han Delegado la Gestión de sus Citas',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryBlue,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (_receivedAuths.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                'No cuenta con autorizaciones recibidas de otros afiliados.',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _receivedAuths.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final a = _receivedAuths[i];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.teal,
                                    child: Icon(
                                      Icons.verified,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    a.principalName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Cédula: ${a.principalIdCard} | Vínculo: ${a.relationship}',
                                  ),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(90, 36),
                                    ),
                                    onPressed: () {
                                      // Navegar a reservar con la cédula del beneficiario
                                      context.push('/book-appointment');
                                    },
                                    child: const Text('Agendar'),
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
            ),
    );
  }
}
