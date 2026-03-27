// Ticket Model for Issue Reporting & Communication

class TicketResponse {
  final String responseId;
  final String authorUid;
  final String authorName;
  final String authorRole;
  final String message;
  final DateTime createdAt;

  TicketResponse({
    required this.responseId,
    required this.authorUid,
    required this.authorName,
    required this.authorRole,
    required this.message,
    required this.createdAt,
  });

  factory TicketResponse.fromJson(Map<String, dynamic> json) {
    return TicketResponse(
      responseId: json['response_id'] ?? '',
      authorUid: json['author_uid'] ?? '',
      authorName: json['author_name'] ?? '',
      authorRole: json['author_role'] ?? 'user',
      message: json['message'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'response_id': responseId,
      'author_uid': authorUid,
      'author_name': authorName,
      'author_role': authorRole,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Ticket {
  final String ticketId;
  final String reporterUid;
  final String reporterName;
  final String? assignedTo;
  final String category; // leak, malfunction, complaint, other
  final String subject;
  final String description;
  final String status; // open, in_progress, resolved, closed
  final String priority; // low, medium, high, critical
  final List<TicketResponse> responses;
  final String? zoneId;
  final String? adminUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  Ticket({
    required this.ticketId,
    required this.reporterUid,
    required this.reporterName,
    this.assignedTo,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    this.responses = const [],
    this.zoneId,
    this.adminUid,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      ticketId: json['ticket_id'] ?? '',
      reporterUid: json['reporter_uid'] ?? '',
      reporterName: json['reporter_name'] ?? '',
      assignedTo: json['assigned_to'],
      category: json['category'] ?? 'other',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'open',
      priority: json['priority'] ?? 'medium',
      responses: (json['responses'] as List<dynamic>?)
              ?.map((r) => TicketResponse.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      zoneId: json['zone_id'],
      adminUid: json['admin_uid'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticket_id': ticketId,
      'reporter_uid': reporterUid,
      'reporter_name': reporterName,
      'assigned_to': assignedTo,
      'category': category,
      'subject': subject,
      'description': description,
      'status': status,
      'priority': priority,
      'responses': responses.map((r) => r.toJson()).toList(),
      'zone_id': zoneId,
      'admin_uid': adminUid,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  Ticket copyWith({
    String? ticketId,
    String? reporterUid,
    String? reporterName,
    String? assignedTo,
    String? category,
    String? subject,
    String? description,
    String? status,
    String? priority,
    List<TicketResponse>? responses,
    String? zoneId,
    String? adminUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
  }) {
    return Ticket(
      ticketId: ticketId ?? this.ticketId,
      reporterUid: reporterUid ?? this.reporterUid,
      reporterName: reporterName ?? this.reporterName,
      assignedTo: assignedTo ?? this.assignedTo,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      responses: responses ?? this.responses,
      zoneId: zoneId ?? this.zoneId,
      adminUid: adminUid ?? this.adminUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  // Status helpers
  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved';
  bool get isClosed => status == 'closed';

  // Priority color helpers
  String get priorityColor {
    switch (priority) {
      case 'critical':
        return '#EF4444';
      case 'high':
        return '#F97316';
      case 'medium':
        return '#EAB308';
      case 'low':
        return '#22C55E';
      default:
        return '#6B7280';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  String get categoryDisplayName {
    switch (category) {
      case 'leak':
        return 'Leakage';
      case 'malfunction':
        return 'Device Malfunction';
      case 'complaint':
        return 'Complaint';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  static const List<String> categories = [
    'leak',
    'malfunction',
    'complaint',
    'other'
  ];
  static const List<String> priorities = ['low', 'medium', 'high', 'critical'];
  static const List<String> statuses = [
    'open',
    'in_progress',
    'resolved',
    'closed'
  ];
}
