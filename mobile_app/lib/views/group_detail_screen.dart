import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'member_detail_screen.dart';
import 'add_member_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final VoidCallback? onUpdate;

  const GroupDetailScreen({super.key, required this.group, this.onUpdate});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _groupData = {};
  Map<String, dynamic> _summary = {};
  List<dynamic> _members = [];

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
    _tabController = TabController(length: 3, vsync: this);
    _loadGroupDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupDetail() async {
    setState(() => _isLoading = true);
    try {
      final groupId = widget.group['id']?.toString() ?? '';
      final data = await ApiService.fetchGroupDetail(groupId);
      if (mounted) {
        setState(() {
          _groupData = data['group'] ?? {};
          _summary = data['summary'] ?? {};
          _members = data['members'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone, String name) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent('Hello $name, this is a reminder regarding your membership dues.');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchWhatsAppBroadcast(List<dynamic> pending) async {
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending members to remind! 🎉')),
      );
      return;
    }
    // Launch WhatsApp for first pending member and notify user
    final first = pending.first;
    final phone = first['phone']?.toString() ?? '';
    final name = first['fullName']?.toString() ?? 'Resident';
    await _launchWhatsApp(phone, name);
  }

  @override
  Widget build(BuildContext context) {
    final groupName = _groupData['name'] ?? widget.group['name'] ?? 'Room Detail';
    final planName = _groupData['parentPlan']?['name'] ?? widget.group['planName'] ?? 'Standard Plan';
    final planPrice = (_groupData['parentPlan']?['price'] as num?)?.toInt() ?? (widget.group['price'] as num?)?.toInt() ?? 0;
    final schedule = _groupData['schedule'] ?? widget.group['schedule'] ?? '';
    final capacity = (_groupData['capacity'] as num?)?.toInt() ?? (widget.group['capacity'] as num?)?.toInt() ?? _members.length;

    final paidMembers = _members.where((m) => m['status'] == 'PAID').toList();
    final pendingMembers = _members.where((m) => m['status'] != 'PAID').toList();

    final totalCapacity = capacity > 0 ? capacity : (_members.isNotEmpty ? _members.length : 1);
    final occupancyPercent = ((_members.length / totalCapacity) * 100).clamp(0, 100).round();
    final isFullyOccupied = _members.length >= totalCapacity && totalCapacity > 0;

    final collected = (_summary['collected'] as num?)?.toInt() ?? 0;
    final pending = (_summary['pending'] as num?)?.toInt() ?? 0;
    final totalRevenue = collected + pending;

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: textPrimary),
            ),
            if (planName.isNotEmpty)
              Text(
                planName,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryGreen),
            onPressed: _loadGroupDetail,
            tooltip: 'Refresh Room',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadGroupDetail,
              color: primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room Snapshot Card (Matching Stitch room_detail.html)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Banner Strip
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryGreen,
                                  Color(0xFF00855D),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isFullyOccupied ? secondaryContainer : Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(9999),
                                      ),
                                      child: Text(
                                        isFullyOccupied ? 'Fully Occupied' : '${totalCapacity - _members.length} Spots Left',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isFullyOccupied ? onSecondaryContainer : Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      groupName,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    schedule.isNotEmpty ? schedule : 'Standard Schedule',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Summary Details Body
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Plan Info Strip
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECEEF0),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.bed_outlined, size: 18, color: primaryGreen),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              planName,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                                            ),
                                            const Text(
                                              'Due 1st of every month',
                                              style: TextStyle(fontSize: 11, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (planPrice > 0)
                                      Text(
                                        '₹$planPrice/bed',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryGreen),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Occupancy Progress Gauge
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'OCCUPANCY',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textSecondary, letterSpacing: 0.5),
                                          ),
                                          Text(
                                            '${_members.length} / $totalCapacity Beds ($occupancyPercent%)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: primaryGreen),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(9999),
                                        child: Container(
                                          height: 8,
                                          width: double.infinity,
                                          color: const Color(0xFFE0E3E5),
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: (occupancyPercent / 100.0).clamp(0.0, 1.0),
                                            child: Container(color: primaryGreen),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Mini Financial Ledger Tile
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECEEF0),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Total Revenue', style: TextStyle(fontSize: 11, color: textSecondary)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '₹$totalRevenue/mo',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECEEF0),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Collection Status', style: TextStyle(fontSize: 11, color: textSecondary)),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: pendingMembers.isNotEmpty ? errorRed : primaryGreen,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  pendingMembers.isNotEmpty ? '${pendingMembers.length} Pending' : 'All Clear ✓',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: pendingMembers.isNotEmpty ? errorRed : primaryGreen,
                                                  ),
                                                ),
                                              ],
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // WhatsApp Smart Quick Action Bar (Matching Stitch room_detail.html)
                    if (pendingMembers.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _launchWhatsAppBroadcast(pendingMembers),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: secondaryContainer.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'WhatsApp Reminder to Pending (${pendingMembers.length})',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onSecondaryContainer),
                                    ),
                                    const Text(
                                      'Auto-includes 1-tap UPI payment link',
                                      style: TextStyle(fontSize: 11, color: onSecondaryContainer),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: onSecondaryContainer),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Residents Roster Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Assigned Residents',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECEEF0),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                '${_members.length} Beds',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Occupied: $occupancyPercent%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Segmented Filter Pills for Members
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEEF0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        labelColor: textPrimary,
                        unselectedLabelColor: textSecondary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        tabs: [
                          Tab(text: 'All (${_members.length})'),
                          Tab(text: 'Pending (${pendingMembers.length})'),
                          Tab(text: 'Paid (${paidMembers.length})'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tab Views
                    SizedBox(
                      height: _members.isEmpty ? 220 : (_members.length * 150.0).clamp(220.0, 900.0),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildResidentList(_members),
                          _buildResidentList(pendingMembers),
                          _buildResidentList(paidMembers),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryGreen,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Add Resident',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddMemberScreen(
                initialGroupId: widget.group['id']?.toString(),
                initialPlanId: widget.group['planId']?.toString(),
              ),
            ),
          ).then((_) {
            _loadGroupDetail();
            widget.onUpdate?.call();
          });
        },
      ),
    );
  }

  Widget _buildResidentList(List<dynamic> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFECEEF0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.people_outline_rounded, size: 28, color: Color(0xFF6D7A72)),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Residents in this Tab',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap "+ Add Resident" below to assign members here.',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final m = list[i];
        final name = m['fullName'] ?? 'Unknown Resident';
        final phone = m['phone'] ?? '';
        final status = m['status'] ?? 'UNPAID';
        final amount = (m['planAmount'] as num?)?.toInt() ?? 0;
        final isPaid = status == 'PAID';
        final isFrozen = status == 'FROZEN';

        final initials = name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: isPaid
                ? null
                : const Border(left: BorderSide(color: errorRed, width: 4)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isPaid
                          ? const Color(0xFFE6E8EA)
                          : isFrozen
                              ? const Color(0xFFE0F2FE)
                              : const Color(0xFFFFDAD6),
                      child: Text(
                        initials.isNotEmpty ? initials : 'R',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isPaid ? primaryGreen : (isFrozen ? const Color(0xFF0284C7) : errorRed),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 15, color: primaryGreen),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            phone.isNotEmpty ? '+91 $phone' : 'No phone recorded',
                            style: const TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? secondaryContainer
                            : (isFrozen ? const Color(0xFFBAE6FD) : const Color(0xFFFFDAD6)),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        isPaid ? 'PAID' : (isFrozen ? 'FROZEN' : 'UNPAID'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPaid ? onSecondaryContainer : (isFrozen ? const Color(0xFF0369A1) : errorRed),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Payment Info Sub-strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPaid ? Icons.check_circle : Icons.warning_amber_rounded,
                            size: 14,
                            color: isPaid ? primaryGreen : errorRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPaid ? 'Paid ₹$amount for cycle' : 'Rent Pending: ₹$amount',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isPaid ? textPrimary : errorRed,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Direct UPI',
                        style: TextStyle(fontSize: 10, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Actions Row (Stitch buttons)
                Row(
                  children: [
                    if (phone.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE0E3E5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.call_outlined, size: 14, color: textSecondary),
                          label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary)),
                          onPressed: () => _launchCall(phone),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFECEEF0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: primaryGreen),
                          label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryGreen)),
                          onPressed: () => _launchWhatsApp(phone, name),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.receipt_long_outlined, size: 18, color: textSecondary),
                      tooltip: 'View Full Ledger',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberDetailScreen(member: m),
                          ),
                        ).then((_) {
                          _loadGroupDetail();
                          widget.onUpdate?.call();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
