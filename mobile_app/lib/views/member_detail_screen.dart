import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'payment_confirmation_dialog.dart';

class MemberDetailScreen extends StatefulWidget {
  final Map<String, dynamic> member;

  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _memberDetails;
  List<dynamic> _paidSchedules = [];
  List<dynamic> _unpaidSchedules = [];
  List<dynamic> _frozenSchedules = [];

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    setState(() => _isLoading = true);
    try {
      final memberId = widget.member['id'];
      final details = await ApiService.fetchMemberDetails(memberId);
      final schedulesData = await ApiService.fetchMemberSchedules(memberId);

      setState(() {
        _memberDetails = details['member'] ?? widget.member;
        _paidSchedules = schedulesData['paidSchedules'] ?? [];
        _unpaidSchedules = schedulesData['unpaidSchedules'] ?? [];
        _frozenSchedules = schedulesData['frozenSchedules'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading member details: $e');
      setState(() {
        _memberDetails = widget.member;
        _isLoading = false;
      });
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openWhatsApp(String phone, String text) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleMarkPaid(dynamic schedule) async {
    final amount = (schedule['amount'] as num?)?.toDouble() ?? 0.0;
    final success = await ApiService.markAsPaid(schedule['id'], amount);
    if (success) {
      if (!mounted) return;
      final action = await showDialog<PaymentConfirmationAction>(
        context: context,
        builder: (ctx) => PaymentConfirmationDialog(
          memberName: _memberDetails?['fullName'] ?? widget.member['fullName'] ?? 'Member',
          amount: amount,
          monthYear: schedule['monthYear'] ?? 'Current Month',
        ),
      );

      if (action == PaymentConfirmationAction.sendInvoice || action == PaymentConfirmationAction.sendPersonalMessage) {
        final phone = _memberDetails?['phone'] ?? widget.member['phone'] ?? '';
        final name = _memberDetails?['fullName'] ?? widget.member['fullName'] ?? 'Member';
        final msg = 'Hi $name, thank you for your payment of ₹${amount.toInt()} for ${schedule['monthYear']}.';
        await _openWhatsApp(phone, msg);
      }

      await _loadMemberData();
    }
  }

  Future<void> _handleMarkUnpaid(dynamic schedule) async {
    final memberName = _memberDetails?['fullName'] ?? widget.member['fullName'] ?? 'Member';
    final confirm = await PaymentConfirmationDialog.showUnpaidWarningModal(context, memberName);
    if (confirm == true) {
      await ApiService.markAsUnpaid(schedule['id'], confirmed: true);
      await _loadMemberData();
    }
  }

  Future<void> _handleFreeze(dynamic schedule) async {
    final success = await ApiService.freezeMonth(schedule['id']);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Month frozen successfully. Excluded from pending dues.')),
      );
      await _loadMemberData();
    }
  }

  Future<void> _handleUnfreeze(dynamic schedule) async {
    final success = await ApiService.unfreezeMonth(schedule['id']);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Month unfrozen back to Unpaid.')),
      );
      await _loadMemberData();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF059669);
    final member = _memberDetails ?? widget.member;
    final name = member['fullName'] ?? 'Unknown';
    final phone = member['phone'] ?? '';
    final planName = member['plan']?['name'] ?? member['duration'] ?? 'Standard Plan';
    final groupName = member['group']?['name'] ?? 'No Group';
    final joiningDate = member['joiningDate'] != null
        ? DateTime.parse(member['joiningDate'].toString()).toString().split(' ')[0]
        : 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: primaryGreen),
            onPressed: () {
              // Edit member action
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit member feature ready')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Information Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Personal Information',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.phone_rounded, color: Color(0xFF0284C7)),
                                    onPressed: () => _makePhoneCall(phone),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat_rounded, color: Color(0xFF10B981)),
                                    onPressed: () => _openWhatsApp(phone, 'Hi $name, regarding your RentTrack account:'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(),
                          _buildInfoRow('Full Name', name),
                          _buildInfoRow('Phone Number', phone),
                          if (member['dateOfBirth'] != null)
                            _buildInfoRow('Date of Birth', member['dateOfBirth'].toString().split('T')[0]),
                          if (member['notes'] != null && member['notes'].toString().isNotEmpty)
                            _buildInfoRow('Notes', member['notes']),
                          // Custom fields rendering
                          if (member['customFieldsData'] != null && member['customFieldsData'] is Map) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Custom Fields',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            ...(member['customFieldsData'] as Map).entries.map(
                                  (e) => _buildInfoRow(e.key.toString(), e.value.toString()),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Membership Information Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Membership Information',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          const Divider(),
                          _buildInfoRow('Plan', planName),
                          _buildInfoRow('Batch / Group', groupName),
                          _buildInfoRow('Join Date', joiningDate),
                          _buildInfoRow('Duration', member['duration'] ?? 'Monthly'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment History Header
                  const Text(
                    'Payment History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  // Unpaid History Section
                  if (_unpaidSchedules.isNotEmpty) ...[
                    Row(
                      children: const [
                        Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Unpaid History',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._unpaidSchedules.map((s) => _buildScheduleTile(s, status: 'UNPAID')),
                    const SizedBox(height: 16),
                  ],

                  // Frozen History Section
                  if (_frozenSchedules.isNotEmpty) ...[
                    Row(
                      children: const [
                        Icon(Icons.ac_unit_rounded, color: Color(0xFF0284C7), size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Frozen History',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._frozenSchedules.map((s) => _buildScheduleTile(s, status: 'FROZEN')),
                    const SizedBox(height: 16),
                  ],

                  // Paid History Section
                  Row(
                    children: const [
                      Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Paid History',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_paidSchedules.isEmpty)
                    const Text('No paid history yet.', style: TextStyle(color: Color(0xFF94A3B8))),
                  ..._paidSchedules.map((s) => _buildScheduleTile(s, status: 'PAID')),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(dynamic schedule, {required String status}) {
    final amount = (schedule['amount'] as num?)?.toDouble() ?? 0.0;
    final monthYear = schedule['monthYear'] ?? 'Month';
    final id = schedule['id']?.toString().substring(0, 8) ?? '';

    Color badgeColor;
    String badgeText;

    if (status == 'PAID') {
      badgeColor = const Color(0xFF10B981);
      badgeText = 'PAID';
    } else if (status == 'FROZEN') {
      badgeColor = const Color(0xFF0284C7);
      badgeText = 'FROZEN ❄️';
    } else {
      badgeColor = Colors.redAccent;
      badgeText = 'UNPAID';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        title: Row(
          children: [
            Text(monthYear, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
        subtitle: Text('ID: #$id • Amount: ₹${amount.toInt()}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'UNPAID') ...[
              IconButton(
                icon: const Icon(Icons.ac_unit_rounded, color: Color(0xFF0284C7), size: 20),
                tooltip: 'Freeze Month',
                onPressed: () => _handleFreeze(schedule),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleMarkPaid(schedule),
                child: const Text('Mark Paid', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ] else if (status == 'FROZEN') ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.wb_sunny_rounded, color: Color(0xFF0284C7), size: 16),
                label: const Text('Unfreeze', style: TextStyle(color: Color(0xFF0284C7), fontSize: 12)),
                onPressed: () => _handleUnfreeze(schedule),
              ),
            ] else if (status == 'PAID') ...[
              TextButton(
                onPressed: () => _handleMarkUnpaid(schedule),
                child: const Text('Mark Unpaid', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
