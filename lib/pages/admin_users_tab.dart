import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_authentication_service.dart';
import '../services/firebase_device_service.dart';
import '../models/device_model.dart';
import 'add_device_page.dart';
import 'user_dashboard.dart';
import 'test_history_page.dart';

class AdminUsersTab extends StatefulWidget {
  final User currentAdmin;
  final bool isReadOnly; // Added read-only flag

  const AdminUsersTab({
    super.key, 
    required this.currentAdmin, 
    this.isReadOnly = false, // Default to false for full Admin view
  });

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _authService = FirebaseAuthenticationService();
  final _deviceService = FirebaseDeviceService();
  List<User> _users = [];
  Map<String, List<Device>> _userDevices = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _authService.getUsersForAdmin(widget.currentAdmin.uid);
      
      // Fetch devices for each user
      final deviceMap = <String, List<Device>>{};
      for (var user in users) {
        final devices = await _deviceService.getUserDevices(user.uid);
        deviceMap[user.uid] = devices;
      }

      setState(() {
        _users = users;
        _userDevices = deviceMap;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final mobileController = TextEditingController();
    final passwordController = TextEditingController(); // New password controller
    String selectedRole = 'subordinate';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: mobileController,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Initial Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'subordinate', child: Text('Subordinate (Read-only)')),
                    DropdownMenuItem(value: 'user', child: Text('End User')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || emailController.text.isEmpty) {
                  return;
                }
                
                try {
                  if (selectedRole == 'subordinate') {
                    await _authService.addSubordinate(
                      email: emailController.text.trim(),
                      password: passwordController.text,
                      fullName: nameController.text.trim(),
                      mobileNumber: mobileController.text.trim(),
                    );
                  } else {
                    await _authService.addUser(
                      email: emailController.text.trim(),
                      password: passwordController.text,
                      fullName: nameController.text.trim(),
                      mobileNumber: mobileController.text.trim(),
                    );
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding user: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to remove ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _authService.deleteUser(user.uid);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting user: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Managed Users (${_users.length})',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (!widget.isReadOnly) 
                ElevatedButton.icon(
                  onPressed: _showAddUserDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? const Center(child: Text('No users managed under your account.'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final devices = _userDevices[user.uid] ?? [];
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: user.role == 'subordinate' ? Colors.teal : Colors.blue,
                          child: Icon(
                            user.role == 'subordinate' ? Icons.badge : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(user.fullName),
                        subtitle: Text('${user.email} • ${devices.length} Devices'),
                        children: [
                          const Divider(height: 0),
                          // List of devices
                          if (devices.isEmpty)
                             const Padding(
                               padding: EdgeInsets.all(16.0),
                               child: Text('No devices registered under this user.', style: TextStyle(fontStyle: FontStyle.italic)),
                             )
                          else
                            ...devices.map((device) => ListTile(
                              leading: Icon(
                                Icons.circle, 
                                color: device.effectiveStatus == DeviceStatus.active ? Colors.green : Colors.grey,
                                size: 12,
                              ),
                              title: Text(device.deviceName),
                              subtitle: Text(device.deviceId),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Live View
                                  IconButton(
                                    icon: const Icon(Icons.live_tv, color: Colors.blue, size: 20),
                                    tooltip: 'Live Readings',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserDashboard(user: user),
                                        ),
                                      );
                                    },
                                  ),
                                  // Reports View
                                  IconButton(
                                    icon: const Icon(Icons.assessment, color: Colors.orange, size: 20),
                                    tooltip: 'Reports',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TestHistoryPage(deviceId: device.deviceId),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            )),
                          
                          const Divider(height: 0),
                          // Actions for this user
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!widget.isReadOnly && user.role == 'user') ...[
                                  TextButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddDevicePage(
                                            user: widget.currentAdmin,
                                            targetUser: user,
                                          ),
                                        ),
                                      );
                                      if (result == true) _loadUsers();
                                    },
                                    icon: const Icon(Icons.add_to_queue, size: 18),
                                    label: const Text('Add Device'),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (!widget.isReadOnly)
                                  TextButton.icon(
                                    onPressed: () => _deleteUser(user),
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                    label: const Text('Remove User', style: TextStyle(color: Colors.red)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
