// Staff Management Page - Admin Only
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_authentication_service.dart';
import '../services/zone_service.dart';
import '../models/zone_model.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final _authService = FirebaseAuthenticationService();
  final _zoneService = ZoneService();

  List<User> _allUsers = [];
  List<Zone> _zones = [];
  bool _isLoading = true;
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await _authService.getAllUsers();
      final zones = await _zoneService.getAllZones();
      setState(() {
        _allUsers = users;
        _zones = zones;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<User> get _filteredUsers {
    if (_roleFilter == 'all') return _allUsers;
    return _allUsers.where((u) => u.role == _roleFilter).toList();
  }

  Future<void> _changeRole(User user, String newRole) async {
    try {
      await _authService.assignRole(
        targetUid: user.uid,
        newRole: newRole,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} is now ${newRole.toUpperCase()}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showRoleDialog(User user) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role: ${user.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current role: ${user.role.toUpperCase()}'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.shield, color: Colors.blue),
              title: const Text('Admin'),
              subtitle: const Text('Full system access'),
              selected: user.role == 'admin',
              onTap: () => Navigator.pop(context, 'admin'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.green),
              title: const Text('Subordinate'),
              subtitle: const Text('Read-only monitoring'),
              selected: user.role == 'subordinate',
              onTap: () => Navigator.pop(context, 'subordinate'),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.grey),
              title: const Text('User'),
              subtitle: const Text('Basic access'),
              selected: user.role == 'user',
              onTap: () => Navigator.pop(context, 'user'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
        ],
      ),
    );

    if (result != null && result != user.role) {
      await _changeRole(user, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Summary cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                    child: _statCard(
                        'Admins',
                        _allUsers.where((u) => u.role == 'admin').length,
                        Colors.blue)),
                const SizedBox(width: 8),
                Expanded(
                    child: _statCard(
                        'Officers',
                        _allUsers
                            .where((u) => u.role == 'subordinate')
                            .length,
                        Colors.green)),
                const SizedBox(width: 8),
                Expanded(
                    child: _statCard(
                        'Users',
                        _allUsers.where((u) => u.role == 'user').length,
                        Colors.grey)),
              ],
            ),
          ),
          // Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('Admin', 'admin'),
                const SizedBox(width: 8),
                _filterChip('Subordinate', 'subordinate'),
                const SizedBox(width: 8),
                _filterChip('User', 'user'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getRoleColor(user.role),
                              child: Text(
                                user.fullName.isNotEmpty
                                    ? user.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(user.fullName),
                            subtitle: Text(
                              '${user.email}\n${user.role.toUpperCase()}${user.assignedZone != null ? ' • Zone: ${_getZoneName(user.assignedZone!)}' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showRoleDialog(user),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getZoneName(String zoneId) {
    try {
      return _zones.firstWhere((z) => z.zoneId == zoneId).zoneName;
    } catch (_) {
      return zoneId;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.blue;
      case 'subordinate':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _statCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _roleFilter = value),
      selectedColor: const Color(0xFF3B82F6),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
