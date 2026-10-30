import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iess_turnos_app/app/theme/app_theme.dart';
import 'package:iess_turnos_app/core/constants/api_constants.dart';
import 'package:iess_turnos_app/features/auth/viewmodels/auth_viewmodel.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<dynamic> _users = [];
  List<dynamic> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final usersRes = await client.dio.get(ApiConstants.usersList);
      final auditRes = await client.dio.get(ApiConstants.auditLogs);

      setState(() {
        _users = usersRes.data as List;
        _auditLogs = auditRes.data as List;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administrativo y Auditoría'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.blue.shade100,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Usuarios'),
            Tab(icon: Icon(Icons.security), text: 'Logs de Auditoría (RF09)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab Usuarios
                ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final u = _users[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.lightBlue,
                          child: Text(u['fullName']?[0] ?? 'U'),
                        ),
                        title: Text(u['fullName'] ?? ''),
                        subtitle: Text(
                          'Cédula: ${u['idCard']} | Email: ${u['email']}',
                        ),
                        trailing: Chip(
                          label: Text(
                            (u['roles'] as List?)?.join(', ') ?? 'AFFILIATE',
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Tab Auditoría Sanitizada (RF09 / R09)
                ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _auditLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final log = _auditLogs[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Chip(
                                  label: Text('${log['statusCode']}'),
                                  backgroundColor: log['statusCode'] < 400
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  labelStyle: TextStyle(
                                    color: log['statusCode'] < 400
                                        ? AppTheme.successGreen
                                        : AppTheme.errorRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    log['action'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'HH:mm:ss dd/MM',
                                  ).format(DateTime.parse(log['createdAt'])),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Recurso: ${log['resource']} | IP: ${log['ipAddress']}',
                            ),
                            if (log['metadata'] != null)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Metadatos Sanitizados: ${log['metadata']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
