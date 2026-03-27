// Admin Dashboard - Multi-Device Monitoring
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/device_model.dart';
import '../services/authentication_service.dart';
import '../services/firebase_device_service.dart'; // Change to Firebase service
import '../widgets/device_card_widget.dart';
import 'add_device_page.dart';
import 'admin_device_details.dart';
import 'staff_management_page.dart';
import 'zone_management_page.dart';
import 'ticket_pages.dart';
import 'announcements_page.dart';
import 'export_page.dart';
import 'admin_users_tab.dart';

class AdminDashboard extends StatefulWidget {
  final User user;

  const AdminDashboard({
    super.key,
    required this.user,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final AuthenticationService _authService;
  late final FirebaseDeviceService _deviceService;

  List<Device> _devices = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _statistics = {};
  int _selectedFilterTab = 0; // 0 = All, 1 = Active, 2 = Offline, 3 = Maintenance
  int _selectedNavTab = 0;

  @override
  void initState() {
    super.initState();
    _authService = AuthenticationService();
    _deviceService = FirebaseDeviceService();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      // Use the new aggregation methods instead of getUserDevices
      final devices = await _deviceService.getDevicesForAdmin(widget.user.uid);
      final stats = await _deviceService.getDeviceStatisticsForAdmin(widget.user.uid);

      setState(() {
        _devices = devices;
        _statistics = stats;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load devices: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Device> _getFilteredDevices() {
    switch (_selectedFilterTab) {
      case 0: // All
        return _devices;
      case 1: // Active
        return _devices.where((d) => d.effectiveStatus == DeviceStatus.active).toList();
      case 2: // Offline
        return _devices.where((d) => d.effectiveStatus == DeviceStatus.offline).toList();
      case 3: // Maintenance
        return _devices.where((d) => d.effectiveStatus == DeviceStatus.maintenance).toList();
      default:
        return _devices;
    }
  }

  // Removed simulateDeviceUpdate call as it's for mock service only


  Future<void> _deleteDevice(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Are you sure you want to delete ${device.deviceName}?'),
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

    if (confirmed == true) {
      try {
        await _deviceService.deleteDevice(device.deviceId, widget.user.uid);
        await _loadDevices();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting device: $e')),
          );
        }
      }
    }
  }

  Future<void> _showDeviceDetails(Device device) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminDeviceDetailsPage(device: device),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'profile',
                child: const Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
                onTap: () => _showProfileDialog(),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'staff',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const StaffManagementPage())),
                child: const Row(
                  children: [
                    Icon(Icons.people, size: 20, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Staff Management'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'zones',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ZoneManagementPage())),
                child: const Row(
                  children: [
                    Icon(Icons.map, size: 20, color: Colors.teal),
                    SizedBox(width: 12),
                    Text('Zone Management'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'tickets',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TicketListPage(currentUser: widget.user))),
                child: const Row(
                  children: [
                    Icon(Icons.support_agent, size: 20, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Tickets'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'announcements',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AnnouncementsPage(currentUser: widget.user))),
                child: const Row(
                  children: [
                    Icon(Icons.campaign, size: 20, color: Colors.purple),
                    SizedBox(width: 12),
                    Text('Announcements'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'export',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ExportPage(currentUser: widget.user))),
                child: const Row(
                  children: [
                    Icon(Icons.download, size: 20, color: Colors.indigo),
                    SizedBox(width: 12),
                    Text('Export Data'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                onTap: _logout,
                child: const Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedNavTab,
              children: [
                _buildDevicesTab(),
                AdminUsersTab(currentAdmin: widget.user),
                TicketListPage(currentUser: widget.user, isEmbedded: true),
                ExportPage(currentUser: widget.user, isEmbedded: true),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavTab,
        onDestinationSelected: (index) {
          setState(() => _selectedNavTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Tickets',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Export',
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Header Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${widget.user.fullName}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Administrator • ${widget.user.location}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Error Message
          if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 8),
          ),

          // Statistics Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics, color: Color(0xFF3B82F6), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'System Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatisticsRow(),
                ],
              ),
            ),
          ),

          // Filter Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Devices',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab('All', 0, _devices.length),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          'Active',
                          1,
                          _devices.where((d) => d.effectiveStatus == DeviceStatus.active).length,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          'Offline',
                          2,
                          _devices.where((d) => d.effectiveStatus == DeviceStatus.offline).length,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          'Maintenance',
                          3,
                          _devices.where((d) => d.effectiveStatus == DeviceStatus.maintenance).length,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Devices Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.devices, color: Color(0xFF3B82F6), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Devices',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_getFilteredDevices().length} device${_getFilteredDevices().length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Device List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final filteredDevices = _getFilteredDevices();

                if (filteredDevices.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.devices_other,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No devices found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final device = filteredDevices[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DeviceCard(
                    device: device,
                    onTap: () => _showDeviceDetails(device),
                    onDelete: () => _deleteDevice(device),
                  ),
                );
              },
              childCount: _getFilteredDevices().isEmpty ? 1 : _getFilteredDevices().length,
            ),
          ),

          // Bottom Padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDevicePage,
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
    );
  }

  void _showAddDevicePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDevicePage(user: widget.user),
      ),
    ).then((result) {
      if (result == true) {
        _loadDevices();
      }
    });
  }

  Widget _buildStatisticsRow() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total Devices',
          '${_statistics['total_devices'] ?? 0}',
          Icons.devices,
          Colors.blue,
        ),
        _buildStatCard(
          'Active',
          '${_statistics['active_devices'] ?? 0}',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Offline',
          '${_statistics['offline_devices'] ?? 0}',
          Icons.error,
          Colors.red,
        ),
        _buildStatCard(
          'Maintenance',
          '${_statistics['maintenance_devices'] ?? 0}',
          Icons.settings,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, int tabIndex, int count) {
    final isSelected = _selectedFilterTab == tabIndex;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilterTab = tabIndex);
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xFF3B82F6),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileField('Name', widget.user.fullName),
            _profileField('Email', widget.user.email),
            _profileField('Role', widget.user.role.toUpperCase()),
            _profileField('Location', widget.user.location),
            _profileField('Devices (Org)', '${_devices.length}'), 
            _profileField(
              'Member Since',
              _formatDate(widget.user.createdAt),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
