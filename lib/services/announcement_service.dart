import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement_model.dart';

class AnnouncementService {
  static final AnnouncementService _instance =
      AnnouncementService._internal();

  factory AnnouncementService() {
    return _instance;
  }

  AnnouncementService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Create a new announcement (admin only)
  Future<Announcement> createAnnouncement({
    required String title,
    required String message,
    required String authorUid,
    required String authorName,
    String targetZone = 'all',
    String priority = 'medium',
    DateTime? expiresAt,
  }) async {
    try {
      final now = DateTime.now();
      final announcementId = 'ann_${now.millisecondsSinceEpoch}';

      final announcement = Announcement(
        announcementId: announcementId,
        title: title,
        message: message,
        authorUid: authorUid,
        authorName: authorName,
        targetZone: targetZone,
        priority: priority,
        createdAt: now,
        expiresAt: expiresAt,
      );

      await _firestore
          .collection('announcements')
          .doc(announcementId)
          .set(announcement.toJson());

      print('✅ Announcement created: $announcementId');
      return announcement;
    } catch (e) {
      print('❌ Error creating announcement: $e');
      rethrow;
    }
  }

  /// Get all active announcements (non-expired)
  Future<List<Announcement>> getAnnouncements() async {
    try {
      final querySnapshot = await _firestore
          .collection('announcements')
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Announcement.fromJson(doc.data()))
          .where((a) => !a.isExpired)
          .toList();
    } catch (e) {
      print('❌ Error fetching announcements: $e');
      rethrow;
    }
  }

  /// Get announcements for a specific zone (or 'all')
  Future<List<Announcement>> getAnnouncementsForZone(String? zoneId) async {
    try {
      final querySnapshot = await _firestore
          .collection('announcements')
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Announcement.fromJson(doc.data()))
          .where((a) =>
              !a.isExpired &&
              (a.targetZone == 'all' || a.targetZone == zoneId))
          .toList();
    } catch (e) {
      print('❌ Error fetching zone announcements: $e');
      rethrow;
    }
  }

  /// Delete announcement
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      await _firestore
          .collection('announcements')
          .doc(announcementId)
          .delete();
      print('✅ Announcement deleted: $announcementId');
    } catch (e) {
      print('❌ Error deleting announcement: $e');
      rethrow;
    }
  }

  /// Real-time stream of active announcements
  Stream<List<Announcement>> getAnnouncementStream() {
    return _firestore
        .collection('announcements')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Announcement.fromJson(doc.data()))
          .where((a) => !a.isExpired)
          .toList();
    });
  }

  /// Count active announcements
  Future<int> countActiveAnnouncements() async {
    try {
      final announcements = await getAnnouncements();
      return announcements.length;
    } catch (e) {
      print('❌ Error counting announcements: $e');
      return 0;
    }
  }
}
