// Announcements Page - Admin creates, all roles view
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/announcement_model.dart';
import '../services/announcement_service.dart';
import '../services/zone_service.dart';
import '../models/zone_model.dart';

class AnnouncementsPage extends StatefulWidget {
  final User currentUser;

  const AnnouncementsPage({super.key, required this.currentUser});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final _announcementService = AnnouncementService();
  final _zoneService = ZoneService();

  List<Announcement> _announcements = [];
  List<Zone> _zones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final announcements = widget.currentUser.isAdmin
          ? await _announcementService.getAnnouncements()
          : await _announcementService
              .getAnnouncementsForZone(widget.currentUser.assignedZone);
      final zones = await _zoneService.getAllZones();
      setState(() {
        _announcements = announcements;
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

  Future<void> _createAnnouncement() async {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String targetZone = 'all';
    String priority = 'medium';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Announcement title',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Announcement message...',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: targetZone,
                  decoration: const InputDecoration(labelText: 'Target'),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('All Zones')),
                    ..._zones.map((z) => DropdownMenuItem(
                        value: z.zoneId, child: Text(z.zoneName))),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => targetZone = v ?? 'all'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(
                        value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(
                        value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => priority = v ?? 'medium'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Post')),
          ],
        ),
      ),
    );

    if (result == true && titleCtrl.text.trim().isNotEmpty) {
      try {
        await _announcementService.createAnnouncement(
          title: titleCtrl.text.trim(),
          message: messageCtrl.text.trim(),
          authorUid: widget.currentUser.uid,
          authorName: widget.currentUser.fullName,
          targetZone: targetZone,
          priority: priority,
        );
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Announcement posted!'),
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
  }

  Future<void> _deleteAnnouncement(Announcement ann) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text('Delete "${ann.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await _announcementService.deleteAnnouncement(ann.announcementId);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No announcements'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _announcements.length,
                    itemBuilder: (context, index) {
                      final ann = _announcements[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.campaign,
                                    color: _getPriorityColor(ann.priority),
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
                                  if (widget.currentUser.isAdmin)
                                    IconButton(
                                      onPressed: () =>
                                          _deleteAnnouncement(ann),
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red, size: 20),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(ann.message),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      ann.targetZone == 'all'
                                          ? 'All Zones'
                                          : _getZoneName(ann.targetZone),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(
                                      ann.priorityDisplayName,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: _getPriorityColor(
                                            ann.priority)
                                        .withValues(alpha: 0.1),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDate(ann.createdAt),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              Text(
                                'By ${ann.authorName}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: widget.currentUser.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _createAnnouncement,
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.add),
              label: const Text('New Announcement'),
            )
          : null,
    );
  }

  String _getZoneName(String zoneId) {
    try {
      return _zones.firstWhere((z) => z.zoneId == zoneId).zoneName;
    } catch (_) {
      return zoneId;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
