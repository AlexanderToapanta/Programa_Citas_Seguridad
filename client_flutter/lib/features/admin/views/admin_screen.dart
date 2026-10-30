import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import 'package:iess_turnos_app/core/constants/api_constants.dart';
import 'package:iess_turnos_app/features/auth/viewmodels/auth_viewmodel.dart';

// ──────────────────────────────────────────────────────────────────────────────
// PANTALLA ADMINISTRADOR – Solo gestión de usuarios y datos administrativos
// ──────────────────────────────────────────────────────────────────────────────

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  bool _isLoading = false;
  List<dynamic> _users = [];
  String _searchQuery = '';

  static String _rolLabel(String role) {
    switch (role) {
      case 'AFFILIATE':      return 'Afiliado';
      case 'REPRESENTATIVE': return 'Representante';
      case 'RECEPTIONIST':   return 'Recepcionista';
      case 'DOCTOR':         return 'Médico';
      case 'ADMIN':          return 'Administrador';
      case 'SUPPORT':        return 'Soporte';
      default:               return role;
    }
  }

  static Color _rolColor(String role) {
    switch (role) {
      case 'AFFILIATE':      return Colors.blue.shade700;
      case 'REPRESENTATIVE': return Colors.teal.shade700;
      case 'RECEPTIONIST':   return Colors.purple.shade700;
      case 'DOCTOR':         return Colors.green.shade700;
      case 'ADMIN':          return Colors.indigo.shade800;
      case 'SUPPORT':        return Colors.orange.shade700;
      default:               return Colors.grey.shade700;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.get(ApiConstants.usersList);
      setState(() {
        _users = res.data as List;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) {
      final name = (u['fullName'] ?? '').toString().toLowerCase();
      final card = (u['idCard'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || card.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalAfiliados = _users.where((u) {
      final roles = (u['roles'] as List?) ?? [];
      return roles.contains('AFFILIATE') || roles.contains('REPRESENTATIVE');
    }).length;
    final totalMedicos = _users.where((u) {
      final roles = (u['roles'] as List?) ?? [];
      return roles.contains('DOCTOR');
    }).length;
    final totalPersonal = _users.where((u) {
      final roles = (u['roles'] as List?) ?? [];
      return roles.contains('RECEPTIONIST') ||
             roles.contains('ADMIN') ||
             roles.contains('SUPPORT');
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administrativo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Tarjetas resumen ──────────────────────────────
                          Text(
                            'Resumen del Sistema',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatCard(
                                'Total Usuarios',
                                '${_users.length}',
                                Icons.people,
                                AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 10),
                              _buildStatCard(
                                'Afiliados',
                                '$totalAfiliados',
                                Icons.person,
                                Colors.teal.shade700,
                              ),
                              const SizedBox(width: 10),
                              _buildStatCard(
                                'Médicos',
                                '$totalMedicos',
                                Icons.medical_services,
                                Colors.green.shade700,
                              ),
                              const SizedBox(width: 10),
                              _buildStatCard(
                                'Personal',
                                '$totalPersonal',
                                Icons.admin_panel_settings,
                                Colors.indigo.shade700,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Buscador ──────────────────────────────────────
                          Text(
                            'Gestión de Usuarios',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar por nombre, cédula o correo...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // ── Lista de usuarios ─────────────────────────────────────
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    sliver: _filteredUsers.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No se encontraron usuarios.',
                                  style:
                                      TextStyle(color: AppTheme.textMuted),
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                if (i < _filteredUsers.length) {
                                  return _buildUserCard(_filteredUsers[i]);
                                }
                                if (i == _filteredUsers.length) {
                                  return const SizedBox(height: 24);
                                }
                                return null;
                              },
                              childCount: _filteredUsers.length + 1,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<dynamic, dynamic> u) {
    final roles = (u['roles'] as List?)?.map((r) => r.toString()).toList() ??
        ['AFFILIATE'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _rolColor(roles.first).withOpacity(0.15),
          child: Text(
            (u['fullName'] ?? 'U')[0].toUpperCase(),
            style: TextStyle(
              color: _rolColor(roles.first),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          u['fullName'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Cédula: ${u['idCard']} · ${u['email']}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Wrap(
          spacing: 4,
          children: roles.map((r) {
            return Chip(
              label: Text(
                _rolLabel(r),
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _rolColor(r).withOpacity(0.12),
              labelStyle: TextStyle(color: _rolColor(r)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PANTALLA SOPORTE – Solo logs de auditoría (RF09)
// ──────────────────────────────────────────────────────────────────────────────

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  bool _isLoading = false;
  List<dynamic> _auditLogs = [];
  String _filterStatus = 'TODOS';

  static const _statusOpciones = ['TODOS', 'EXITOSOS', 'ERRORES'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.get(ApiConstants.auditLogs);
      setState(() {
        _auditLogs = res.data as List;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredLogs {
    if (_filterStatus == 'EXITOSOS') {
      return _auditLogs.where((l) => (l['statusCode'] ?? 500) < 400).toList();
    } else if (_filterStatus == 'ERRORES') {
      return _auditLogs.where((l) => (l['statusCode'] ?? 500) >= 400).toList();
    }
    return _auditLogs;
  }

  @override
  Widget build(BuildContext context) {
    final errores =
        _auditLogs.where((l) => (l['statusCode'] ?? 500) >= 400).length;
    final exitosos = _auditLogs.length - errores;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registros de Auditoría'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Resumen ───────────────────────────────────────
                          Row(
                            children: [
                              _buildCountCard(
                                'Total Registros',
                                '${_auditLogs.length}',
                                Icons.list_alt,
                                AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 10),
                              _buildCountCard(
                                'Exitosos',
                                '$exitosos',
                                Icons.check_circle_outline,
                                AppTheme.successGreen,
                              ),
                              const SizedBox(width: 10),
                              _buildCountCard(
                                'Errores',
                                '$errores',
                                Icons.error_outline,
                                AppTheme.errorRed,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Filtros ───────────────────────────────────────
                          Row(
                            children: _statusOpciones.map((op) {
                              final selected = _filterStatus == op;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(op),
                                  selected: selected,
                                  onSelected: (_) =>
                                      setState(() => _filterStatus = op),
                                  selectedColor:
                                      AppTheme.primaryBlue.withOpacity(0.15),
                                  checkmarkColor: AppTheme.primaryBlue,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? AppTheme.primaryBlue
                                        : AppTheme.textDark,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),

                  // ── Lista de logs ─────────────────────────────────────────
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    sliver: _filteredLogs.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('No hay registros disponibles.'),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                if (i < _filteredLogs.length) {
                                  return _buildLogCard(_filteredLogs[i]);
                                }
                                if (i == _filteredLogs.length) {
                                  return const SizedBox(height: 24);
                                }
                                return null;
                              },
                              childCount: _filteredLogs.length + 1,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCountCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<dynamic, dynamic> log) {
    final code = log['statusCode'] ?? 0;
    final esError = code >= 400;
    final colorFondo =
        esError ? Colors.red.shade50 : Colors.green.shade50;
    final colorTexto =
        esError ? AppTheme.errorRed : AppTheme.successGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorFondo,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$code',
                    style: TextStyle(
                      color: colorTexto,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    log['action'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  log['createdAt'] != null
                      ? DateFormat('HH:mm:ss dd/MM')
                          .format(DateTime.parse(log['createdAt']))
                      : '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Recurso: ${log['resource'] ?? ''} · IP: ${log['ipAddress'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            if (log['metadata'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Metadatos: ${log['metadata']}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
