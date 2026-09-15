import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'member_detail_screen.dart';
import 'group_detail_screen.dart';

class PlanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  const PlanDetailScreen({super.key, required this.plan});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _planData = {};
  List<dynamic> _members = [];
  List<dynamic> _groups = [];
  List<dynamic> _payments = [];
  Map<String, dynamic> _summary = {};

  static const primaryGreen = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPlanDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlanDetail() async {
    setState(() => _isLoading = true);
    try {
      final planId = widget.plan['id']?.toString() ?? '';
      final data = await ApiService.fetchPlanDetail(planId);
      if (mounted) {
        setState(() {
          _planData = data['plan'] ?? {};
          _summary = data['summary'] ?? {};
          _members = data['members'] ?? [];
          _groups = data['groups'] ?? [];
          _payments = data['payments'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddGroupDialog() {
    final nameCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();
    final capacityCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Group/Batch', style: TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Group Name *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Morning Batch, Slot A',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Schedule (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: scheduleCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Mon-Fri 6:00AM',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Capacity (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: capacityCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 20',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final planId = widget.plan['id']?.toString() ?? '';
              final cap = int.tryParse(capacityCtrl.text.trim());
              final success = await ApiService.createGroup(planId, name,
                  schedule: scheduleCtrl.text.trim().isEmpty ? null : scheduleCtrl.text.trim(),
                  capacity: cap);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group created successfully!'),
                      backgroundColor: primaryGreen,
                    ),
                  );
                  _loadPlanDetail();
                }
              }
            },
            child: const Text('Create Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planName = _planData['name'] ?? widget.plan['name'] ?? 'Plan';
    final planPrice = (_planData['price'] ?? widget.plan['price'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              planName,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            Text(
              '₹$planPrice / month',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryGreen,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: primaryGreen,
          tabs: const [
            Tab(text: 'Members'),
            Tab(text: 'Groups'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : Column(
              children: [
                // Summary Bar
                _buildSummaryBar(),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMembersTab(),
                      _buildGroupsTab(),
                      _buildPaymentsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBar() {
    final totalMembers = _summary['totalMembers'] ?? 0;
    final paid = _summary['paidMembersCount'] ?? 0;
    final pending = _summary['pendingMembersCount'] ?? 0;
    final collected = (_summary['collected'] as num?)?.toInt() ?? 0;
    final pendingAmt = (_summary['pending'] as num?)?.toInt() ?? 0;
    final frozen = _summary['frozenMembers'] ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statChip(totalMembers.toString(), 'Total', const Color(0xFF6366F1)),
            const SizedBox(width: 8),
            _statChip(paid.toString(), 'Paid', const Color(0xFF059669)),
            const SizedBox(width: 8),
            _statChip(pending.toString(), 'Pending', const Color(0xFFF97316)),
            const SizedBox(width: 8),
            _statChip(frozen.toString(), 'Frozen ❄️', const Color(0xFF0284C7)),
            const SizedBox(width: 8),
            _statChip('₹$collected', 'Collected', const Color(0xFF059669)),
            const SizedBox(width: 8),
            _statChip('₹$pendingAmt', 'Due', const Color(0xFFEF4444)),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMembersTab() {
    if (_members.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 52, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text('No members in this plan',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 15)),
            SizedBox(height: 8),
            Text('Add members and assign to this plan.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (ctx, i) {
        final m = _members[i];
        final status = m['status'] ?? 'UNPAID';
        final amount = (m['amount'] as num?)?.toInt() ?? 0;
        final name = m['fullName'] ?? 'Member';
        final group = m['groupName'] ?? 'Direct';
        final phone = m['phone'] ?? '';

        Color badgeColor;
        if (status == 'PAID') {
          badgeColor = const Color(0xFF059669);
        } else if (status == 'FROZEN') {
          badgeColor = const Color(0xFF0284C7);
        } else {
          badgeColor = const Color(0xFFF97316);
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'M',
                style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
            subtitle: Text('$group • ₹$amount', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status == 'FROZEN' ? '❄️ Frozen' : status,
                style: TextStyle(color: badgeColor, fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(member: {'fullName': name, 'phone': phone, 'id': m['id']}),
                ),
              ).then((_) => _loadPlanDetail());
            },
          ),
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Add group button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: primaryGreen),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_rounded, color: primaryGreen),
          label: const Text('Add New Group / Batch', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
          onPressed: _openAddGroupDialog,
        ),
        const SizedBox(height: 16),
        if (_groups.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No groups yet. Create batches to organise members by schedule or slot.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          )
        else
          ..._groups.map((g) => _buildGroupCard(g)),
      ],
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> g) {
    final name = g['name'] ?? 'Group';
    final schedule = g['schedule'] ?? '';
    final capacity = g['capacity'];
    final totalMembers = g['totalMembers'] ?? 0;
    final paidCount = g['paidCount'] ?? 0;
    final pendingCount = g['pendingCount'] ?? 0;
    final collected = (g['collected'] as num?)?.toInt() ?? 0;
    final pending = (g['pending'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: g)),
        ).then((_) => _loadPlanDetail());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.group_rounded, size: 20, color: primaryGreen),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        if (schedule.isNotEmpty)
                          Text(schedule,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _groupStat('$totalMembers Members', const Color(0xFF6366F1)),
                _groupStat('$paidCount Paid', const Color(0xFF059669)),
                _groupStat('$pendingCount Pending', const Color(0xFFF97316)),
                if (capacity != null) _groupStat('Cap: $capacity', const Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text('₹$collected',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                        const Text('Collected',
                            style: TextStyle(fontSize: 10, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text('₹$pending',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFF97316))),
                        const Text('Pending',
                            style: TextStyle(fontSize: 10, color: Color(0xFFEA580C))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupStat(String label, Color color) {
    return Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color));
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 52, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text('No payments recorded yet.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (ctx, i) {
        final p = _payments[i];
        final memberName = p['member']?['fullName'] ?? 'Member';
        final amount = (p['amountPaid'] as num?)?.toInt() ?? 0;
        final date = p['paymentDate'] != null
            ? DateTime.parse(p['paymentDate'].toString()).toString().split(' ')[0]
            : 'N/A';
        final method = p['paymentMethod'] ?? 'CASH';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: primaryGreen, size: 22),
            ),
            title: Text(memberName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
            subtitle: Text('$date • $method',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            trailing: Text('₹$amount',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: primaryGreen)),
          ),
        );
      },
    );
  }
}
