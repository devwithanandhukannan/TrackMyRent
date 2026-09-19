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

  static const primaryGreen = Color(0xFF006948);
  static const secondaryContainer = Color(0xFF6CF8BB);
  static const onSecondaryContainer = Color(0xFF00714D);
  static const surfaceBg = Color(0xFFF7F9FB);
  static const textPrimary = Color(0xFF191C1E);
  static const textSecondary = Color(0xFF3D4A42);
  static const errorRed = Color(0xFFBA1A1A);

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
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse('tel:$cleanPhone');
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
          memberName: _memberDetails?['fullName'] ?? widget.member['fullName'] ?? 'Resident',
          amount: amount,
          monthYear: schedule['monthYear'] ?? 'Current Month',
        ),
      );

      if (action == PaymentConfirmationAction.sendInvoice || action == PaymentConfirmationAction.sendPersonalMessage) {
        final phone = _memberDetails?['phone'] ?? widget.member['phone'] ?? '';
        final name = _memberDetails?['fullName'] ?? widget.member['fullName'] ?? 'Resident';
        final msg = 'Hi $name, thank you for your payment of ₹${amount.toInt()} for ${schedule['monthYear']}.';
        await _openWhatsApp(phone, msg);
      }

      await _loadMemberData();
    }
  }

  Future<void> _handleMarkUnpaid(dynamic schedule) async {
    final memberName = _memberDetails?['fullName'] ?? widget.member['fullName'] ?? 'Resident';
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
        const SnackBar(content: Text('Month frozen. Excluded from pending dues.')),
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
    final member = _memberDetails ?? widget.member;
    final name = member['fullName'] ?? 'Resident Profile';
    final phone = member['phone'] ?? '';
    final planName = member['plan']?['name'] ?? member['duration'] ?? 'Standard Accommodation';
    final groupName = member['group']?['name'] ?? '';
    final joiningDate = member['joiningDate'] != null
        ? DateTime.parse(member['joiningDate'].toString()).toString().split(' ')[0]
        : 'Active';

    final initials = name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase();

    // Financial calculations from real schedules
    double totalPaidAmount = 0.0;
    for (var s in _paidSchedules) {
      totalPaidAmount += (s['amount'] as num?)?.toDouble() ?? 0.0;
    }
    double totalUnpaidAmount = 0.0;
    for (var s in _unpaidSchedules) {
      totalUnpaidAmount += (s['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tenant Profile',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryGreen),
            onPressed: _loadMemberData,
            tooltip: 'Refresh Ledger',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadMemberData,
              color: primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Bento Card (Stitch member_detail.html)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: secondaryContainer,
                                child: Text(
                                  initials.isNotEmpty ? initials : 'R',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECEEF0),
                                            borderRadius: BorderRadius.circular(9999),
                                          ),
                                          child: const Text(
                                            'Active',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      phone.isNotEmpty ? '+91 $phone' : 'No phone',
                                      style: const TextStyle(fontSize: 13, color: textSecondary),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (groupName.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF2F4F6),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.meeting_room_outlined, size: 12, color: primaryGreen),
                                                const SizedBox(width: 4),
                                                Text(groupName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
                                              ],
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2F4F6),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(planName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2F4F6),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('Since $joiningDate', style: const TextStyle(fontSize: 11, color: textSecondary)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Quick Call / WhatsApp Action Row
                          if (phone.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE0E3E5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.phone_outlined, size: 16, color: textSecondary),
                                    label: Text('Call $name', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                                    onPressed: () => _makePhoneCall(phone),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryGreen,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                                    label: const Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                    onPressed: () => _openWhatsApp(phone, 'Hi $name, regarding your rent dues with RentTrack:'),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 14),

                          // Financial Snapshot Bento Cells (Stitch member_detail.html)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F6),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Total Received', style: TextStyle(fontSize: 11, color: textSecondary)),
                                          Icon(Icons.verified_rounded, size: 14, color: primaryGreen),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${totalPaidAmount.toInt()}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryGreen),
                                      ),
                                      Text(
                                        '${_paidSchedules.length} cycles cleared',
                                        style: const TextStyle(fontSize: 10, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F6),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Current Balance', style: TextStyle(fontSize: 11, color: textSecondary)),
                                          Icon(Icons.account_balance_wallet_outlined, size: 14, color: Color(0xFF6D7A72)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${totalUnpaidAmount.toInt()}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: totalUnpaidAmount > 0 ? errorRed : textPrimary,
                                        ),
                                      ),
                                      Text(
                                        totalUnpaidAmount > 0 ? '${_unpaidSchedules.length} cycles pending' : 'All Dues Cleared',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: totalUnpaidAmount > 0 ? errorRed : primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ledger Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 18, color: primaryGreen),
                            SizedBox(width: 6),
                            Text(
                              'Payment Schedules',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFECEEF0)),
                          ),
                          child: const Text(
                            'All Cycles',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Unpaid Schedules (Stitch card with red left stripe)
                    if (_unpaidSchedules.isNotEmpty) ...[
                      ..._unpaidSchedules.map((s) => _buildScheduleCard(s, status: 'UNPAID')),
                    ],

                    // Frozen Schedules (Stitch card with icy blue left stripe)
                    if (_frozenSchedules.isNotEmpty) ...[
                      ..._frozenSchedules.map((s) => _buildScheduleCard(s, status: 'FROZEN')),
                    ],

                    // Paid Schedules (Stitch card with emerald left stripe)
                    if (_paidSchedules.isNotEmpty) ...[
                      ..._paidSchedules.map((s) => _buildScheduleCard(s, status: 'PAID')),
                    ],

                    if (_unpaidSchedules.isEmpty && _paidSchedules.isEmpty && _frozenSchedules.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Text(
                            'No payment cycles recorded yet.',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScheduleCard(dynamic schedule, {required String status}) {
    final amount = (schedule['amount'] as num?)?.toInt() ?? 0;
    final monthYear = schedule['monthYear'] ?? 'Billing Cycle';
    final isPaid = status == 'PAID';
    final isFrozen = status == 'FROZEN';

    final stripeColor = isPaid ? primaryGreen : (isFrozen ? const Color(0xFF0284C7) : errorRed);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: stripeColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      monthYear,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? secondaryContainer
                            : (isFrozen ? const Color(0xFFE0F2FE) : const Color(0xFFFFDAD6)),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        isPaid ? 'PAID' : (isFrozen ? 'FROZEN' : 'UNPAID'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPaid ? onSecondaryContainer : (isFrozen ? const Color(0xFF0284C7) : errorRed),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹$amount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isPaid ? primaryGreen : (isFrozen ? const Color(0xFF0284C7) : textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isPaid ? 'Paid via Direct UPI' : (isFrozen ? 'Excluded from active dues' : 'Due for collection'),
              style: TextStyle(fontSize: 11, color: isPaid ? textSecondary : (isFrozen ? const Color(0xFF0284C7) : errorRed)),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFECEEF0)),
            const SizedBox(height: 10),

            // Actions Row (Stitch buttons)
            Row(
              children: [
                if (!isPaid && !isFrozen) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                      label: const Text('Mark Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      onPressed: () => _handleMarkPaid(schedule),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0E3E5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.ac_unit_rounded, size: 14, color: Color(0xFF0284C7)),
                    label: const Text('Freeze', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
                    onPressed: () => _handleFreeze(schedule),
                  ),
                ] else if (isFrozen) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.wb_sunny_rounded, size: 16, color: Color(0xFF0284C7)),
                      label: const Text('Unfreeze Back to Unpaid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
                      onPressed: () => _handleUnfreeze(schedule),
                    ),
                  ),
                ] else if (isPaid) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0E3E5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 14, color: primaryGreen),
                      label: const Text('Digital Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryGreen)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Invoice verified for $monthYear')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 14, color: errorRed),
                    label: const Text('Revert', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: errorRed)),
                    onPressed: () => _handleMarkUnpaid(schedule),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
