import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'payment_confirmation_dialog.dart';
import 'add_member_screen.dart';

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
  static const surfaceBg = Color(0xFFF7F9FB);
  static const textPrimary = Color(0xFF191C1E);
  static const textSecondary = Color(0xFF3D4A42);
  static const errorRed = Color(0xFFBA1A1A);

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  Future<void> _navigateToEditMember() async {
    final currentMember = _memberDetails ?? widget.member;
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMemberScreen(existingMember: currentMember),
      ),
    );
    if (updated == true && mounted) {
      await _loadMemberData();
    }
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

  Future<void> _handleMarkPaid(dynamic schedule, {String paymentMethod = 'CASH'}) async {
    final amount = (schedule['amount'] as num?)?.toDouble() ?? 0.0;

    // MED-03 FIX: Show error snackbar on failure (was silently ignoring errors before)
    final result = await ApiService.markAsPaid(
      schedule['id'],
      amount,
      paymentMethod: paymentMethod,
    );

    if (result['success'] != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to record payment. Please retry.'),
          backgroundColor: errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    final transactionId = result['transaction']?['id'] as String?;
    final whatsappSent = result['whatsappReceiptSent'] == true;

    final action = await showDialog<PaymentConfirmationAction>(
      context: context,
      builder: (ctx) => PaymentConfirmationDialog(
        memberName: _memberDetails?['fullName'] ?? widget.member['fullName'] ?? 'Resident',
        amount: amount,
        monthYear: schedule['monthYear'] ?? 'Current Month',
        transactionId: transactionId,
        paymentMethod: paymentMethod,
        whatsappReceiptSent: whatsappSent,
      ),
    );

    if (action == PaymentConfirmationAction.sendInvoice) {
      final receiptResult = await ApiService.sendPaymentReceipt(
        scheduleId: schedule['id'],
        transactionId: transactionId,
      );
      if (mounted) {
        final success = receiptResult?['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Receipt sent to WhatsApp' : 'Could not send receipt'),
            backgroundColor: success ? primaryGreen : errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    await _loadMemberData();
  }

  Future<void> _handleSendReminder(dynamic schedule) async {
    final memberName = _memberDetails?['fullName'] ?? widget.member['fullName'] ?? 'Resident';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sending reminder to $memberName...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final res = await ApiService.sendPaymentReminder(schedule['id']);
    if (!mounted) return;

    if (res != null && res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder sent to $memberName'),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send reminder. Check credits in Settings.'),
          backgroundColor: errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSendPaymentLink(dynamic schedule) async {
    final memberName = _memberDetails?['fullName'] ?? widget.member['fullName'] ?? 'Resident';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending payment link...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final res = await ApiService.sendPaymentReminder(schedule['id']);
    if (!mounted) return;

    if (res != null && res['success'] == true) {
      final isCloudSent = res['whatsappApiSent'] == true;
      final directUrl = res['directWhatsAppUrl'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment link sent to $memberName'),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
          action: directUrl != null && !isCloudSent
              ? SnackBarAction(
                  label: 'Open WhatsApp',
                  textColor: Colors.white,
                  onPressed: () => launchUrl(Uri.parse(directUrl), mode: LaunchMode.externalApplication),
                )
              : null,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send payment link. Check credits.'),
          backgroundColor: errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        const SnackBar(content: Text('Cycle frozen')),
      );
      await _loadMemberData();
    }
  }

  Future<void> _handleUnfreeze(dynamic schedule) async {
    final success = await ApiService.unfreezeMonth(schedule['id']);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cycle unfrozen')),
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
            icon: const Icon(Icons.edit_note_rounded, color: primaryGreen, size: 24),
            onPressed: _navigateToEditMember,
            tooltip: 'Edit Tenant Details',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: textSecondary, size: 22),
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
                    // Profile Header Card (Apple Style)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    initials.isNotEmpty ? initials : 'T',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      color: Colors.white,
                                    ),
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
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _navigateToEditMember,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              border: Border.all(color: const Color(0xFFA7F3D0)),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit, size: 11, color: Color(0xFF059669)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Edit',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      phone.isNotEmpty ? '+91 $phone' : 'No phone',
                                      style: const TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500),
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
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
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
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(planName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
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
                          const SizedBox(height: 18),

                          // Quick Call / WhatsApp Action Row (Apple Button Style)
                          if (phone.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      backgroundColor: const Color(0xFFF8FAFC),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.phone_outlined, size: 16, color: textPrimary),
                                    label: Text('Call $name', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                                    onPressed: () => _makePhoneCall(phone),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                                    label: const Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                    onPressed: () => _openWhatsApp(phone, 'Hi $name, regarding your rent dues with RentTrack:'),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Financial Snapshot Bento Cells
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Total Received', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                          Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF10B981)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '₹${totalPaidAmount.toInt()}',
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF10B981), letterSpacing: -0.5),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_paidSchedules.length} cycles cleared',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: totalUnpaidAmount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: totalUnpaidAmount > 0 ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Current Balance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                          Icon(
                                            Icons.account_balance_wallet_outlined,
                                            size: 15,
                                            color: totalUnpaidAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '₹${totalUnpaidAmount.toInt()}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: totalUnpaidAmount > 0 ? const Color(0xFFDC2626) : textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        totalUnpaidAmount > 0 ? '${_unpaidSchedules.length} cycle pending' : 'All Dues Cleared',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: totalUnpaidAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981),
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
                    const SizedBox(height: 20),

                    // Ledger Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Schedules',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.3),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'All Cycles',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          monthYear,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? const Color(0xFFECFDF5)
                                : (isFrozen ? const Color(0xFFF0F9FF) : const Color(0xFFFEF2F2)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isPaid
                                  ? const Color(0xFFA7F3D0)
                                  : (isFrozen ? const Color(0xFFBAE6FD) : const Color(0xFFFECACA)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPaid
                                    ? Icons.check_circle_rounded
                                    : (isFrozen ? Icons.ac_unit_rounded : Icons.schedule_rounded),
                                size: 10,
                                color: isPaid
                                    ? const Color(0xFF065F46)
                                    : (isFrozen ? const Color(0xFF0369A1) : const Color(0xFF991B1B)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPaid ? 'PAID' : (isFrozen ? 'FROZEN' : 'UNPAID'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  color: isPaid
                                      ? const Color(0xFF065F46)
                                      : (isFrozen ? const Color(0xFF0369A1) : const Color(0xFF991B1B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPaid
                          ? 'Settled & Verified'
                          : (isFrozen ? 'Excluded from active dues' : 'Due for collection'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isPaid
                            ? const Color(0xFF059669)
                            : (isFrozen ? const Color(0xFF0284C7) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹$amount',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isPaid ? const Color(0xFF059669) : (isFrozen ? const Color(0xFF0284C7) : textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Actions Row (Apple minimalist style buttons)
            if (!isPaid && !isFrozen) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Send Payment Link',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  onPressed: () => _handleSendPaymentLink(schedule),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A), // Apple dark slate
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
                      label: const Text(
                        'Mark Paid',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      onPressed: () => _handleMarkPaid(schedule),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 13, color: Color(0xFF10B981)),
                      label: const Text(
                        'Remind',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      onPressed: () => _handleSendReminder(schedule),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () => _handleFreeze(schedule),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.ac_unit_rounded, size: 13, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text(
                          'Freeze',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else if (isFrozen) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F9FF),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.wb_sunny_rounded, size: 16, color: Color(0xFF0284C7)),
                  label: const Text(
                    'Unfreeze Cycle Back to Unpaid',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                  ),
                  onPressed: () => _handleUnfreeze(schedule),
                ),
              ),
            ] else if (isPaid) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFF059669)),
                      label: const Text(
                        'Digital Receipt',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Payment verified for $monthYear')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 14, color: errorRed),
                    label: const Text(
                      'Revert',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: errorRed),
                    ),
                    onPressed: () => _handleMarkUnpaid(schedule),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
