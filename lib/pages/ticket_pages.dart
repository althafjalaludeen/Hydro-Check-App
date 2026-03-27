// Ticket Pages - Create, List, Detail Views
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../models/ticket_model.dart';
import '../services/ticket_service.dart';

// === CREATE TICKET PAGE ===
class CreateTicketPage extends StatefulWidget {
  final User currentUser;

  const CreateTicketPage({super.key, required this.currentUser});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ticketService = TicketService();

  String _selectedCategory = 'complaint';
  String _selectedPriority = 'medium';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _ticketService.createTicket(
        reporterUid: widget.currentUser.uid,
        reporterName: widget.currentUser.fullName,
        category: _selectedCategory,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
        adminUid: widget.currentUser.adminUid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Issue'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category
              const Text('Category',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'leak', child: Text('🔵 Leakage')),
                  DropdownMenuItem(
                      value: 'malfunction',
                      child: Text('🟠 Device Malfunction')),
                  DropdownMenuItem(
                      value: 'complaint', child: Text('🔴 Complaint')),
                  DropdownMenuItem(
                      value: 'other', child: Text('⚪ Other')),
                ],
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 16),

              // Priority
              const Text('Priority',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedPriority,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('🟢 Low')),
                  DropdownMenuItem(
                      value: 'medium', child: Text('🟡 Medium')),
                  DropdownMenuItem(value: 'high', child: Text('🟠 High')),
                  DropdownMenuItem(
                      value: 'critical', child: Text('🔴 Critical')),
                ],
                onChanged: (v) => setState(() => _selectedPriority = v!),
              ),
              const SizedBox(height: 16),

              // Subject
              const Text('Subject',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: 'Brief description of the issue',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              const Text('Description',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Provide details about the issue...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Ticket',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === TICKET LIST PAGE ===
class TicketListPage extends StatefulWidget {
  final User currentUser;
  final bool isEmbedded;

  const TicketListPage({
    super.key, 
    required this.currentUser,
    this.isEmbedded = false,
  });

  @override
  State<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends State<TicketListPage> {
  final _ticketService = TicketService();
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String _statusFilter = 'all';
  StreamSubscription<List<Ticket>>? _ticketSubscription;

  @override
  void initState() {
    super.initState();
    _setupTicketStream();
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    super.dispose();
  }

  void _setupTicketStream() {
    setState(() => _isLoading = true);
    
    Stream<List<Ticket>> stream;
    if (widget.currentUser.isAdmin) {
      stream = _ticketService.getTicketsForAdminStream(widget.currentUser.uid);
    } else if (widget.currentUser.isSubordinate) {
      stream = _ticketService.getTicketsForAdminStream(widget.currentUser.adminUid ?? '');
    } else {
      stream = _ticketService.getUserTicketStream(widget.currentUser.uid);
    }

    _ticketSubscription = stream.listen(
      (tickets) {
        if (mounted) {
          setState(() {
            _tickets = tickets;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading tickets: $e')),
          );
        }
      },
    );
  }

  List<Ticket> get _filteredTickets {
    if (_statusFilter == 'all') return _tickets;
    return _tickets.where((t) => t.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isEmbedded ? null : AppBar(
        title: const Text('Tickets'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('Open', 'open'),
                const SizedBox(width: 8),
                _filterChip('In Progress', 'in_progress'),
                const SizedBox(width: 8),
                _filterChip('Resolved', 'resolved'),
                const SizedBox(width: 8),
                _filterChip('Closed', 'closed'),
              ],
            ),
          ),
          // Ticket list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTickets.isEmpty
                    ? const Center(child: Text('No tickets found'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredTickets.length,
                        itemBuilder: (context, index) {
                            final ticket = _filteredTickets[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TicketDetailPage(
                                        ticket: ticket,
                                        currentUser: widget.currentUser,
                                      ),
                                    ),
                                  );
                                },
                                leading: _getCategoryIcon(ticket.category),
                                title: Text(ticket.subject,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  '${ticket.reporterName} • ${ticket.categoryDisplayName}',
                                ),
                                trailing: _buildStatusChip(ticket.status),
                              ),
                            );
                          },
                        ),
          ),
        ],
      ),
      floatingActionButton: widget.currentUser.role == 'user'
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateTicketPage(currentUser: widget.currentUser),
                  ),
                );
              },
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.add),
              label: const Text('New Ticket'),
            )
          : null,
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: const Color(0xFF3B82F6),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: FontWeight.w600,
      ),
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
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(fontSize: 10, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// === TICKET DETAIL PAGE ===
class TicketDetailPage extends StatefulWidget {
  final Ticket ticket;
  final User currentUser;

  const TicketDetailPage({
    super.key,
    required this.ticket,
    required this.currentUser,
  });

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final _ticketService = TicketService();
  final _responseController = TextEditingController();
  late Ticket _ticket;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _refreshTicket();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _refreshTicket() async {
    try {
      final updated = await _ticketService.getTicket(_ticket.ticketId);
      if (updated != null && mounted) {
        setState(() => _ticket = updated);
      }
    } catch (_) {}
  }

  Future<void> _sendResponse() async {
    if (_responseController.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _ticketService.addResponse(
        ticketId: _ticket.ticketId,
        authorUid: widget.currentUser.uid,
        authorName: widget.currentUser.fullName,
        authorRole: widget.currentUser.role,
        message: _responseController.text.trim(),
      );
      _responseController.clear();
      await _refreshTicket();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await _ticketService.updateTicketStatus(_ticket.ticketId, newStatus);
      await _refreshTicket();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        actions: [
          if (widget.currentUser.isAdmin)
            PopupMenuButton<String>(
              onSelected: _updateStatus,
              itemBuilder: (_) => Ticket.statuses
                  .map((s) => PopupMenuItem(
                        value: s,
                        child: Text(s.replaceAll('_', ' ').toUpperCase()),
                      ))
                  .toList(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 4),
                    Text('Status'),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(_ticket.subject,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(_ticket.categoryDisplayName),
                        avatar:
                            const Icon(Icons.category, size: 16),
                      ),
                      Chip(
                        label: Text(_ticket.statusDisplayName),
                        backgroundColor: _getStatusColor(_ticket.status)
                            .withValues(alpha: 0.15),
                      ),
                      Chip(
                        label: Text(_ticket.priority.toUpperCase()),
                        backgroundColor: Colors.orange.shade50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reported by ${_ticket.reporterName} • ${_formatDate(_ticket.createdAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const Divider(height: 24),

                  // Description
                  const Text('Description',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(_ticket.description),
                  ),
                  const SizedBox(height: 24),

                  // Responses
                  Text(
                    'Responses (${_ticket.responses.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_ticket.responses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                          child: Text('No responses yet',
                              style: TextStyle(color: Colors.grey))),
                    ),
                  ..._ticket.responses.map((resp) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: resp.authorRole == 'admin'
                              ? Colors.blue.shade50
                              : resp.authorRole == 'subordinate'
                                  ? Colors.green.shade50
                                  : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: resp.authorRole == 'admin'
                                ? Colors.blue.shade200
                                : resp.authorRole == 'subordinate'
                                    ? Colors.green.shade200
                                    : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  resp.authorName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    resp.authorRole.toUpperCase(),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(resp.createdAt),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(resp.message),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),

          // Response input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _responseController,
                    decoration: InputDecoration(
                      hintText: 'Type a response...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _sendResponse,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
