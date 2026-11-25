import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../state/app_state.dart';

/// Full backend control room for users with `users.is_admin`.
///
/// Reads and writes go through /api/admin/console; every privileged action is
/// recorded in the admin_audit table by the server.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _sql = TextEditingController();

  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _audit = [];
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _errors = [];
  List<String> _serverLog = [];
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _sqlResult;
  bool _showServerLog = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _sql.dispose();
    super.dispose();
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) {
    return context.read<AppState>().api.request(method, path, body: body);
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadOverview(),
      _loadTables(),
      _loadErrors(),
      _loadUsers(),
    ]);
  }

  Future<void> _loadOverview() async {
    try {
      final overview = await _request('GET', '/api/admin/console/overview');
      final audit = await _request('GET', '/api/admin/console/audit');
      if (!mounted) return;
      setState(() {
        _overview = Map<String, dynamic>.from(overview as Map);
        _audit = (audit['entries'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (error) {
      _toast(error);
    }
  }

  Future<void> _loadTables() async {
    try {
      final data = await _request('GET', '/api/admin/console/tables');
      if (!mounted) return;
      setState(() {
        _tables = (data['tables'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (error) {
      _toast(error);
    }
  }

  Future<void> _loadErrors() async {
    try {
      final data = await _request('GET', '/api/admin/console/client-errors');
      final log =
          await _request('GET', '/api/admin/console/error-log?lines=200');
      if (!mounted) return;
      setState(() {
        _errors = (data['errors'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _serverLog = (log['lines'] as List).map((e) => e.toString()).toList();
      });
    } catch (error) {
      _toast(error);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final data = await _request('GET', '/api/admin/console/users');
      if (!mounted) return;
      setState(() {
        _users = (data['users'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (error) {
      _toast(error);
    }
  }

  void _toast(Object error) {
    if (!mounted) return;
    final message = error is Exception ? error.toString() : 'Request failed.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _runSql() async {
    final sql = _sql.text.trim();
    if (sql.isEmpty) return;
    final destructive =
        !RegExp(r'^\s*(select|show|explain|with)\b', caseSensitive: false)
            .hasMatch(sql);
    if (destructive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Run write statement?'),
          content: Text(
            'This statement can change or delete data:\n\n'
            '${sql.length > 300 ? '${sql.substring(0, 300)}…' : sql}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      final result = await _request(
        'POST',
        '/api/admin/console/sql',
        body: {'sql': sql},
      );
      if (!mounted) return;
      setState(() => _sqlResult = Map<String, dynamic>.from(result as Map));
      await _loadOverview();
    } catch (error) {
      _toast(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTable(String name) async {
    try {
      final data = await _request(
        'GET',
        '/api/admin/console/tables/$name?limit=50',
      );
      if (!mounted) return;
      final rows = (data['rows'] as List)
          .map((entry) => const JsonEncoder.withIndent('  ').convert(entry))
          .join('\n\n');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$name (${data['total']} rows)'),
          content: SizedBox(
            width: 700,
            height: 460,
            child: SingleChildScrollView(
              child: SelectableText(
                rows.isEmpty ? 'No rows.' : rows,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _toast(error);
    }
  }

  Future<void> _clearClientErrors() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear client errors?'),
        content: const Text('Every reported client error will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _request('DELETE', '/api/admin/console/client-errors');
      await _loadErrors();
    } catch (error) {
      _toast(error);
    }
  }

  Future<void> _updateUser(
    Map<String, dynamic> user,
    Map<String, dynamic> body,
  ) async {
    try {
      await _request(
        'PATCH',
        '/api/admin/console/users/${user['id']}',
        body: body,
      );
      await _loadUsers();
      await _loadOverview();
    } catch (error) {
      _toast(error);
    }
  }

  Future<void> _logoutAll(Map<String, dynamic> user) async {
    try {
      await _request(
        'POST',
        '/api/admin/console/users/${user['id']}/logout-all',
      );
      _toastMessage('Signed ${user['username']} out everywhere.');
    } catch (error) {
      _toast(error);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${user['username']}?'),
        content: const Text(
          'The account, the houses it owns and all of their rooms, tenants '
          'and content are removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _request('DELETE', '/api/admin/console/users/${user['id']}');
      await _loadUsers();
      await _loadOverview();
    } catch (error) {
      _toast(error);
    }
  }

  void _toastMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        title: const Text('Admin console'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Database'),
            Tab(text: 'Logs'),
            Tab(text: 'Users'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _overviewTab(),
          _databaseTab(),
          _logsTab(),
          _usersTab(),
        ],
      ),
    );
  }

  Widget _overviewTab() {
    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_overview == null)
            const LinearProgressIndicator()
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _stat('Users', _overview!['users']),
                _stat('Admins', _overview!['admins']),
                _stat('Houses', _overview!['houses']),
                _stat('Rooms', _overview!['rooms']),
                _stat('Tenants', _overview!['tenants']),
                _stat('Announcements', _overview!['announcements']),
                _stat('Concerns', _overview!['concerns']),
                _stat('Client errors', _overview!['client_errors']),
                _stat('Errors / 24h', _overview!['client_errors_24h']),
                _stat('Auth events', _overview!['auth_events']),
              ],
            ),
            const SizedBox(height: 18),
            _panel([
              _kv('Database size', '${_overview!['db_size']}'),
              _kv('PostgreSQL', '${_overview!['database']}'),
              _kv('Node', '${_overview!['node']}'),
              _kv('Environment', '${_overview!['environment']}'),
              _kv('Uptime', '${_overview!['uptimeSeconds']} s'),
            ]),
          ],
          const SizedBox(height: 18),
          const Text(
            'Recent admin actions',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (_audit.isEmpty)
            Text('Nothing yet.', style: TextStyle(color: AppColors.muted))
          else
            _panel(
              _audit.take(30).map((entry) {
                final details = entry['details'];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${entry['action']} · ${entry['username'] ?? 'system'}',
                  ),
                  subtitle: Text(
                    '${entry['created_at']}'
                    '${details is Map && details['sql'] != null ? '\n${details['sql']}' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _databaseTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'SQL console',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sql,
          maxLines: 6,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'SELECT * FROM users;',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _runSql,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Run'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Statements run immediately as the database role. Write '
                'statements ask for confirmation.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ],
        ),
        if (_sqlResult != null) ...[
          const SizedBox(height: 12),
          _panel([
            Padding(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                '${_sqlResult!['command']} · '
                '${_sqlResult!['rowCount']} row(s)\n'
                '${const JsonEncoder.withIndent('  ').convert(_sqlResult!['rows'])}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 22),
        const Text(
          'Tables',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ..._tables.map(
          (table) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${table['name']}'),
            subtitle: Text('~${table['estimated_rows']} rows'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openTable('${table['name']}'),
          ),
        ),
      ],
    );
  }

  Widget _logsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            ChoiceChip(
              label: const Text('Client errors'),
              selected: !_showServerLog,
              onSelected: (_) => setState(() => _showServerLog = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Server log'),
              selected: _showServerLog,
              onSelected: (_) => setState(() => _showServerLog = true),
            ),
            const Spacer(),
            if (!_showServerLog)
              TextButton.icon(
                onPressed: _clearClientErrors,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_showServerLog)
          _panel([
            Padding(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                _serverLog.isEmpty
                    ? 'No server errors logged.'
                    : _serverLog.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ])
        else if (_errors.isEmpty)
          Text(
            'No client errors reported.',
            style: TextStyle(color: AppColors.muted),
          )
        else
          ..._errors.map(
            (error) => _panel([
              ListTile(
                dense: true,
                title: Text(
                  '${error['message']}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${error['username'] ?? 'anonymous'} · '
                  '${error['platform'] ?? 'unknown'} · '
                  'v${error['app_version'] ?? '?'} · ${error['created_at']}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              if (error['stack'] != null)
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  title: const Text(
                    'Stack trace',
                    style: TextStyle(fontSize: 12),
                  ),
                  children: [
                    SelectableText(
                      '${error['stack']}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ]),
          ),
      ],
    );
  }

  Widget _usersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _users.map((user) {
        final isAdmin = user['is_admin'] == true;
        final status = '${user['status']}';
        return _panel([
          ListTile(
            title: Text('${user['username']}'),
            subtitle: Text(
              '${user['email']}\n$status · '
              '${user['owned_houses']} house(s) · '
              '${user['memberships']} membership(s) · '
              'last login ${user['last_login_at'] ?? 'never'}',
              style: const TextStyle(fontSize: 11),
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'admin':
                    _updateUser(user, {'is_admin': !isAdmin});
                    break;
                  case 'status':
                    _updateUser(user,
                        {'status': status == 'active' ? 'disabled' : 'active'});
                    break;
                  case 'logout':
                    _logoutAll(user);
                    break;
                  case 'delete':
                    _deleteUser(user);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'admin',
                  child: Text(isAdmin ? 'Remove admin' : 'Make admin'),
                ),
                PopupMenuItem(
                  value: 'status',
                  child: Text(status == 'active' ? 'Disable' : 'Enable'),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Sign out everywhere'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete account'),
                ),
              ],
            ),
            leading: CircleAvatar(
              backgroundColor: isAdmin ? AppColors.primary : AppColors.surface2,
              child: Text(
                '${user['username']}'.isEmpty
                    ? '?'
                    : '${user['username']}'[0].toUpperCase(),
                style: TextStyle(
                  color: isAdmin ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ]);
      }).toList(),
    );
  }

  Widget _stat(String label, Object? value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _panel(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              key,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
