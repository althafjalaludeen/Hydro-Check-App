// Announcement Model for Admin Broadcasts

class Announcement {
  final String announcementId;
  final String title;
  final String message;
  final String authorUid;
  final String authorName;
  final String targetZone; // zone ID or 'all'
  final String priority; // low, medium, high, critical
  final DateTime createdAt;
  final DateTime? expiresAt;

  Announcement({
    required this.announcementId,
    required this.title,
    required this.message,
    required this.authorUid,
    required this.authorName,
    this.targetZone = 'all',
    this.priority = 'medium',
    required this.createdAt,
    this.expiresAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      announcementId: json['announcement_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      authorUid: json['author_uid'] ?? '',
      authorName: json['author_name'] ?? '',
      targetZone: json['target_zone'] ?? 'all',
      priority: json['priority'] ?? 'medium',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'announcement_id': announcementId,
      'title': title,
      'message': message,
      'author_uid': authorUid,
      'author_name': authorName,
      'target_zone': targetZone,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  String get priorityDisplayName {
    switch (priority) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }
}
