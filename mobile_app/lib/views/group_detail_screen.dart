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

  static const primaryGreen = Color(0xFF059669);

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
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone, String name) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent('Hello $name, this is a reminder regarding your membership payment.');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupName = _groupData['name'] ?? widget.group['name'] ?? 'Group Detail';
    final planName = _groupData['parentPlan']?['name'] ?? widget.group['planName'] ?? '';
    final schedule = _groupData['schedule'] ?? widget.group['schedule'] ?? '';
    final capacity = _groupData['capacity'] ?? widget.group['capacity'];

    final paidMembers = _members.where((m) => m['status'] == 'PAID').toList();
    final pendingMembers = _members.where((m) => m['status'] == 'UNPAID').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
            ),
            if (planName.isNotEmpty)
              Text(
                'Plan: $planName',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupDetail,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: primaryGreen,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: primaryGreen,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(text: 'Paid (${paidMembers.length})'),
                Tab(text: 'Pending (${pendingMembers.length})'),
                Tab(text: 'All (${_members.length})'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : Column(
              children: [
                _buildHeaderInfo(schedule, capacity),
                _buildSummaryBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMemberList(paidMembers, isPendingTab: false),
                      _buildMemberList(pendingMembers, isPendingTab: true),
                      _buildMemberList(_members, isPendingTab: false),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryGreen,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddMemberScreen(),
            ),
          ).then((_) {
            _loadGroupDetail();
            widget.onUpdate?.call();
          });
        },
      ),
    );
  }

  Widget _buildHeaderInfo(String schedule, dynamic capacity) {
    if (schedule.isEmpty && capacity == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF1F5F9),
      child: Row(
        children: [
          if (schedule.isNotEmpty) ...[
            const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(schedule, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            const SizedBox(width: 16),
          ],
          if (capacity != null) ...[
            const Icon(Icons.people_outline_rounded, size: 14, color: Color(0xFF475569)),
            const SizedBox(width: 4),
            Text('Capacity: $capacity', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final totalMembers = _summary['totalMembers'] ?? 0;
    final paidCount = _summary['paidCount'] ?? 0;
    final pendingCount = _summary['pendingCount'] ?? 0;
    final collected = (_summary['collected'] as num?)?.toInt() ?? 0;
    final pending = (_summary['pending'] as num?)?.toInt() ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statChip(totalMembers.toString(), 'Total', const Color(0xFF6366F1)),
          _statChip('$paidCount (₹$collected)', 'Paid', primaryGreen),
          _statChip('$pendingCount (₹$pending)', 'Pending', const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMemberList(List<dynamic> list, {required bool isPendingTab}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPendingTab ? Icons.check_circle_outline_rounded : Icons.people_outline_rounded,
              size: 48,
              color: const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 8),
            Text(
              isPendingTab ? 'No pending members in this group! 🎉' : 'No members found',
              style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final m = list[i];
        final name = m['fullName'] ?? 'Unknown Member';
        final phone = m['phone'] ?? '';
        final status = m['status'] ?? 'UNPAID';
        final amount = (m['planAmount'] as num?)?.toInt() ?? 0;
        final isPaid = status == 'PAID';
        final isFrozen = status == 'FROZEN';

        Color statusColor;
        String statusLabel;
        if (isPaid) {
          statusColor = primaryGreen;
          statusLabel = 'PAID';
        } else if (isFrozen) {
          statusColor = const Color(0xFF0284C7);
          statusLabel = '❄️ FROZEN';
        } else {
          statusColor = const Color(0xFFEF4444);
          statusLabel = 'PENDING';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPendingTab ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: isPaid
                  ? const Color(0xFFDCFCE7)
                  : isFrozen
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFFEE2E2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'M',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isPaid
                      ? primaryGreen
                      : isFrozen
                          ? const Color(0xFF0284C7)
                          : const Color(0xFFEF4444),
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (phone.isNotEmpty)
                  Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹$amount',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isPaid ? primaryGreen : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isPaid && phone.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 20),
                    onPressed: () => _launchWhatsApp(phone, name),
                    tooltip: 'Send WhatsApp Reminder',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.call_outlined, color: primaryGreen, size: 20),
                    onPressed: () => _launchCall(phone),
                    tooltip: 'Call',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
            onTap: () {
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
        );
      },
    );
  }
}
