// Subordinate Dashboard - Read-Only Monitoring View
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/device_model.dart';
import '../models/zone_model.dart';
import '../services/firebase_authentication_service.dart';
import '../services/firebase_device_service.dart';
import '../services/firebase_alert_service.dart';
import '../services/zone_service.dart';
import '../services/ticket_service.dart';
import '../services/announcement_service.dart';
import '../models/ticket_model.dart';
import '../models/announcement_model.dart';
import 'ticket_pages.dart';
import 'test_history_page.dart';
import 'admin_users_tab.dart'; // Import users tab


class SubordinateDashboard extends StatefulWidget {
  final User user;

  const SubordinateDashboard({super.key, required this.user});

  @override
  State<SubordinateDashboard> createState() => _SubordinateDashboardState();
}

class _SubordinateDashboardState extends State<SubordinateDashboard> {
  final _authService = FirebaseAuthenticationService();
  final _deviceService = FirebaseDeviceService();
  final _alertService = FirebaseAlertService();
  final _zoneService = ZoneService();
  final _ticketService = TicketService();
  final _announcementService = AnnouncementService();

  int _selectedIndex = 0;
  bool _isLoading = true;

  List<Device> _devices = [];
  List<Zone> _zones = [];
  List<Ticket> _tickets = [];
   List<Announcement> _announcements = [];
  List<WaterAlert> _alerts = [];
  String? _errorMessage; // Added missing error message field

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Get ALL devices in the organization (now supported for subordinates via the updated service)
      final allDevices = await _deviceService.getDevicesForAdmin(widget.user.uid);

      // 2. Get assigned zones for header context
      final zones =
          await _zoneService.getZonesForSubordinate(widget.user.uid);

      // 3. Load other organization-wide data
      final tickets = await _ticketService.getAllTickets();
      final announcements = await _announcementService
          .getAnnouncementsForZone(widget.user.assignedZone);
      final alerts =
          await _alertService.getUserAlerts(ownerUid: widget.user.uid);

      if (mounted) {
        setState(() {
          _zones = zones;
          _devices = allDevices;
          _tickets = tickets;
          _announcements = announcements;
          _alerts = alerts;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load dashboard data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        title: const Text('Monitoring Dashboard'),
        centerTitle: true,
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                onTap: () => _showProfileDialog(),
                child: const Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
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
              index: _selectedIndex,
              children: [
                _buildDevicesTab(),
                AdminUsersTab(
                  currentAdmin: widget.user, // Subordinates use their own user object as context
                  isReadOnly: true, 
                ),
                _buildAlertsTab(),
                _buildTicketsTab(),
                _buildAnnouncementsTab(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.devices_outlined),
            selectedIcon: const Icon(Icons.devices),
            label: 'Devices (${_devices.length})',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: const Icon(Icons.warning_outlined),
            selectedIcon: const Icon(Icons.warning),
            label: 'Alerts (${_alerts.length})',
          ),
          NavigationDestination(
            icon: const Icon(Icons.support_agent_outlined),
            selectedIcon: const Icon(Icons.support_agent),
            label: 'Tickets (${_tickets.length})',
          ),
          const NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Announcements',
          ),
        ],
      ),
    );
  }

  // === DEVICES TAB ===
  Widget _buildDevicesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
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
                  if (_errorMessage != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Text(
                       _errorMessage!,
                       style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                     ),
                   ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitoring Officer • ${_zones.isNotEmpty ? _zones.map((z) => z.zoneName).join(", ") : "No zone assigned"}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          // Zone Summary
          if (_zones.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.map, color: Color(0xFF059669)),
                            SizedBox(width: 8),
                            Text('Assigned Zones',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._zones.map((zone) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on,
                                  color: Color(0xFF059669)),
                              title: Text(zone.zoneName),
                              subtitle: Text(
                                  '${zone.deviceIds.length} devices'),
                              trailing: Text(zone.description,
                                  style: const TextStyle(fontSize: 12)),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Device List (Read-Only)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.devices, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Text(
                    'Devices (${_devices.length})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          if (_devices.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: Text('No devices in your assigned zones.')),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final device = _devices[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TestHistoryPage(
                              deviceId: device.deviceId,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          leading: Icon(
                            device.isOnline
                                ? Icons.check_circle
                                : Icons.error,
                            color: device.isOnline ? Colors.green : Colors.red,
                          ),
                          title: Text(device.deviceName),
                          subtitle: Text(
                            '${device.location.building}\nTap to view data & export PDF',
                          ),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(
                              device.effectiveStatus.displayName,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: device.isOnline
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: _devices.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // === ALERTS TAB ===
  Widget _buildAlertsTab() {
    return _alerts.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('No alerts', style: TextStyle(fontSize: 18)),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _alerts.length,
            itemBuilder: (context, index) {
              final alert = _alerts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    alert.alertType == 'WATER_NOT_SAFE'
                        ? Icons.warning
                        : Icons.cloud_off,
                    color: Colors.orange,
                  ),
                  title: Text(alert.alertType.replaceAll('_', ' ')),
                  subtitle: Text(
                    'Device: ${alert.deviceId}\n${_formatDate(alert.timestamp)}',
                  ),
                  trailing: alert.acknowledged
                      ? const Icon(Icons.done, color: Colors.green)
                      : const Icon(Icons.circle, color: Colors.orange,
                          size: 12),
                  isThreeLine: true,
                ),
              );
            },
          );
  }

  // === TICKETS TAB ===
  Widget _buildTicketsTab() {
    return _tickets.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No tickets', style: TextStyle(fontSize: 18)),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _tickets.length,
            itemBuilder: (context, index) {
              final ticket = _tickets[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TicketDetailPage(
                          ticket: ticket,
                          currentUser: widget.user,
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
                  leading: _getCategoryIcon(ticket.category),
                  title: Text(ticket.subject,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${ticket.categoryDisplayName} • ${ticket.reporterName}',
                  ),
                  trailing: _buildStatusChip(ticket.status),
                ),
              );
            },
          );
  }

  // === ANNOUNCEMENTS TAB ===
  Widget _buildAnnouncementsTab() {
    return _announcements.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No announcements', style: TextStyle(fontSize: 18)),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _announcements.length,
            itemBuilder: (context, index) {
              final ann = _announcements[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.campaign,
                            color: ann.priority == 'critical'
                                ? Colors.red
                                : ann.priority == 'high'
                                    ? Colors.orange
                                    : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ann.title,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(ann.message),
                      const SizedBox(height: 8),
                      Text(
                        'By ${ann.authorName} • ${_formatDate(ann.createdAt)}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _getCategoryIcon(String category) {
    switch (category) {
      case 'leak':
        return const Icon(Icons.water_drop, color: Colors.blue);
      case 'malfunction':
        return const Icon(Icons.build, color: Colors.orange);
      case 'complaint':
        return const Icon(Icons.report, color: Colors.red);
      default:
        return const Icon(Icons.help, color: Colors.grey);
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'open':
        color = Colors.orange;
        break;
      case 'in_progress':
        color = Colors.blue;
        break;
      case 'resolved':
        color = Colors.green;
        break;
      case 'closed':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 10, color: color),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileField('Name', widget.user.fullName),
            _profileField('Email', widget.user.email),
            _profileField('Role', 'Monitoring Officer'),
            _profileField('Location', widget.user.location),
            _profileField(
                'Assigned Zone',
                _zones.isNotEmpty
                    ? _zones.map((z) => z.zoneName).join(', ')
                    : 'None'),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
