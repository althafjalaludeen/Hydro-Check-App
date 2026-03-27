import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';

class TicketService {
  static final TicketService _instance = TicketService._internal();

  factory TicketService() {
    return _instance;
  }

  TicketService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Create a new ticket (user reports issue)
  Future<Ticket> createTicket({
    required String reporterUid,
    required String reporterName,
    required String category,
    required String subject,
    required String description,
    required String priority,
    String? zoneId,
    String? adminUid,
  }) async {
    try {
      final now = DateTime.now();
      final ticketId = 'ticket_${now.millisecondsSinceEpoch}';

      final ticket = Ticket(
        ticketId: ticketId,
        reporterUid: reporterUid,
        reporterName: reporterName,
        category: category,
        subject: subject,
        description: description,
        status: 'open',
        priority: priority,
        zoneId: zoneId,
        adminUid: adminUid,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection('tickets').doc(ticketId).set(ticket.toJson());

      print('✅ Ticket created: $ticketId');
      return ticket;
    } catch (e) {
      print('❌ Error creating ticket: $e');
      rethrow;
    }
  }

  /// Get tickets submitted by a specific user
  Future<List<Ticket>> getTicketsForUser(String userUid) async {
    try {
      final querySnapshot = await _firestore
          .collection('tickets')
          .where('reporter_uid', isEqualTo: userUid)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Ticket.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching user tickets: $e');
      rethrow;
    }
  }

  /// Get all tickets (admin/subordinate view)
  Future<List<Ticket>> getAllTickets() async {
    try {
      final querySnapshot = await _firestore
          .collection('tickets')
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Ticket.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching all tickets: $e');
      rethrow;
    }
  }

  /// Get tickets filtered by zone
  Future<List<Ticket>> getTicketsByZone(String zoneId) async {
    try {
      final querySnapshot = await _firestore
          .collection('tickets')
          .where('zone_id', isEqualTo: zoneId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Ticket.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching zone tickets: $e');
      rethrow;
    }
  }

  /// Update ticket status (admin only)
  Future<void> updateTicketStatus(String ticketId, String newStatus) async {
    try {
      final updates = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newStatus == 'resolved') {
        updates['resolved_at'] = DateTime.now().toIso8601String();
      }

      await _firestore.collection('tickets').doc(ticketId).update(updates);
      print('✅ Ticket status updated: $ticketId → $newStatus');
    } catch (e) {
      print('❌ Error updating ticket status: $e');
      rethrow;
    }
  }

  /// Assign ticket to a staff member
  Future<void> assignTicket(String ticketId, String assignedToUid) async {
    try {
      await _firestore.collection('tickets').doc(ticketId).update({
        'assigned_to': assignedToUid,
        'status': 'in_progress',
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('✅ Ticket assigned: $ticketId → $assignedToUid');
    } catch (e) {
      print('❌ Error assigning ticket: $e');
      rethrow;
    }
  }

  /// Add a response to a ticket
  Future<void> addResponse({
    required String ticketId,
    required String authorUid,
    required String authorName,
    required String authorRole,
    required String message,
  }) async {
    try {
      final now = DateTime.now();
      final responseId = 'resp_${now.millisecondsSinceEpoch}';

      final response = TicketResponse(
        responseId: responseId,
        authorUid: authorUid,
        authorName: authorName,
        authorRole: authorRole,
        message: message,
        createdAt: now,
      );

      await _firestore.collection('tickets').doc(ticketId).update({
        'responses': FieldValue.arrayUnion([response.toJson()]),
        'updated_at': now.toIso8601String(),
      });

      print('✅ Response added to ticket: $ticketId');
    } catch (e) {
      print('❌ Error adding response: $e');
      rethrow;
    }
  }

  /// Get ticket by ID
  Future<Ticket?> getTicket(String ticketId) async {
    try {
      final doc = await _firestore.collection('tickets').doc(ticketId).get();
      if (!doc.exists) return null;
      return Ticket.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching ticket: $e');
      rethrow;
    }
  }

  /// Real-time stream of all tickets
  Stream<List<Ticket>> getTicketStream() {
    return _firestore
        .collection('tickets')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Ticket.fromJson(doc.data()))
          .toList();
    });
  }

  /// Real-time stream of tickets for a specific admin
  Stream<List<Ticket>> getTicketsForAdminStream(String adminUid) {
    return _firestore
        .collection('tickets')
        .where('admin_uid', isEqualTo: adminUid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Ticket.fromJson(doc.data()))
          .toList();
    });
  }

  /// Real-time stream of tickets for a user
  Stream<List<Ticket>> getUserTicketStream(String userUid) {
    return _firestore
        .collection('tickets')
        .where('reporter_uid', isEqualTo: userUid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Ticket.fromJson(doc.data()))
          .toList();
    });
  }

  /// Count open tickets
  Future<int> countOpenTickets() async {
    try {
      final querySnapshot = await _firestore
          .collection('tickets')
          .where('status', isEqualTo: 'open')
          .count()
          .get();
      return querySnapshot.count ?? 0;
    } catch (e) {
      print('❌ Error counting open tickets: $e');
      return 0;
    }
  }
}
