import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'views/add_member_screen.dart';
import 'views/app_plan_selection_screen.dart';
import 'views/member_detail_screen.dart';
import 'views/plan_detail_screen.dart';
import 'views/settings_screen.dart';
import 'views/login_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isLoggedIn = await ApiService.isLoggedIn();
  runApp(RentTrackApp(isLoggedIn: isLoggedIn));
}

class RentTrackApp extends StatelessWidget {
  final bool isLoggedIn;
  const RentTrackApp({super.key, this.isLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RentTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAF9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF059669),
          secondary: Color(0xFF10B981),
          surface: Colors.white,
        ),
      ),
      home: isLoggedIn ? const MainNavigationScreen() : const LoginScreen(),
    );
  }
}

// Reusable Top Header bar present across Dashboard, Plan, Expense, Report
class RentTrackHeader extends StatelessWidget {
  const RentTrackHeader({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Logout?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your session on RentTrack?',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.clearSession();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (c) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Color(0xFF059669),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'RentTrack',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppPlanSelectionScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showLogoutDialog(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreenView(),
    const PlansScreenView(),
    const ExpensesScreenView(),
    const ReportsScreenView(),
  ];

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF059669);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: SafeArea(
        child: Column(
          children: [
            const RentTrackHeader(),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: primaryGreen,
          unselectedItemColor: const Color(0xFF64748B),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              label: 'Plan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monetization_on_outlined),
              label: 'Expense',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Report',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. DASHBOARD VIEW (Matching Image 1)
// -----------------------------------------------------------------------------
class HomeScreenView extends StatefulWidget {
  const HomeScreenView({super.key});

  @override
  State<HomeScreenView> createState() => _HomeScreenViewState();
}

class _HomeScreenViewState extends State<HomeScreenView> {
  bool _isLoading = true;
  double _totalCollected = 0;
  double _totalPending = 0;
  List<dynamic> _allMembers = [];
  String _activeFilter = 'ALL'; // ALL, PAID, UNPAID, FROZEN

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final summaryRes = await ApiService.fetchFinancialSummary();
      final membersList = await ApiService.fetchMembers();

      if (mounted) {
        setState(() {
          _totalCollected = (summaryRes['summary']?['totalIncome'] as num?)?.toDouble() ?? 0.0;
          _totalPending = (summaryRes['summary']?['totalPending'] as num?)?.toDouble() ?? 0.0;
          _allMembers = membersList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendWhatsAppReminder(String phone, String name, dynamic amount) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent('Hi $name, this is a friendly reminder regarding your pending fee of ₹$amount. Please clear it at your earliest convenience.');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openAddMember() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMemberScreen()),
    );
    if (result == true) {
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF059669);

    final paidMembers = _allMembers.where((m) => m['status'] == 'PAID').toList();
    final unpaidMembers = _allMembers.where((m) => m['status'] == 'UNPAID').toList();
    final frozenMembers = _allMembers.where((m) => m['status'] == 'FROZEN').toList();

    List<dynamic> displayedMembers = _allMembers;
    if (_activeFilter == 'PAID') displayedMembers = paidMembers;
    if (_activeFilter == 'UNPAID') displayedMembers = unpaidMembers;
    if (_activeFilter == 'FROZEN') displayedMembers = frozenMembers;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Add Member Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openAddMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text(
                    'Add member',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Month and year selector card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Month and year',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'September 2026',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metrics Rows (4 cards)
            Row(
              children: [
                // Card 1: All members
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.people_outline_rounded,
                                size: 18,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'All members',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_allMembers.length}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Card 2: Total collected
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.payments_outlined,
                                size: 18,
                                color: primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Collected',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '₹${_totalCollected.toInt()}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Card 3: Paid members
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                                color: primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Paid Members',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${paidMembers.length}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Card 4: Unpaid dues
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Pending Dues',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              '₹${_totalPending.toInt()}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${unpaidMembers.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
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
            const SizedBox(height: 16),

            // QUICK ACTIONS Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QUICK ACTIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE6F4EE),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'View members',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: primaryGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE6F4EE),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Open payments',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: primaryGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Members List Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_allMembers.length} Members',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('All (${_allMembers.length})', 'ALL', primaryGreen),
                        const SizedBox(width: 8),
                        _buildFilterPill('Paid (${paidMembers.length})', 'PAID', primaryGreen),
                        const SizedBox(width: 8),
                        _buildFilterPill('Unpaid (${unpaidMembers.length})', 'UNPAID', const Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        _buildFilterPill('Frozen (${frozenMembers.length}) ❄️', 'FROZEN', const Color(0xFF0284C7)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // List of members or empty message
                  if (_isLoading)
                    const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: primaryGreen)))
                  else if (displayedMembers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No members in this view.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    ...displayedMembers.map((m) {
                      final name = m['fullName'] ?? 'Member';
                      final phone = m['phone'] ?? '';
                      final status = m['status'] ?? 'PAID';
                      final amount = m['amount'] ?? 0;
                      final isPaid = status == 'PAID';
                      final isFrozen = status == 'FROZEN';

                      Color badgeBg;
                      Color badgeText;
                      String statusLabel;
                      if (isPaid) {
                        badgeBg = const Color(0xFFDCFCE7);
                        badgeText = const Color(0xFF166534);
                        statusLabel = 'PAID';
                      } else if (isFrozen) {
                        badgeBg = const Color(0xFFE0F2FE);
                        badgeText = const Color(0xFF0284C7);
                        statusLabel = '❄️ FROZEN';
                      } else {
                        badgeBg = const Color(0xFFFEE2E2);
                        badgeText = const Color(0xFF991B1B);
                        statusLabel = 'UNPAID';
                      }

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MemberDetailScreen(member: m),
                            ),
                          );
                          _loadDashboardData();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isFrozen ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAF9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFrozen
                                  ? const Color(0xFFBAE6FD)
                                  : status == 'UNPAID'
                                      ? const Color(0xFFFECACA)
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (!isPaid && !isFrozen && phone.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
                                      tooltip: 'Send WhatsApp Reminder',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _sendWhatsAppReminder(phone, name, amount),
                                    ),
                                  if (!isPaid && !isFrozen && phone.isNotEmpty)
                                    const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹$amount',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: isPaid ? primaryGreen : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: badgeText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String code, Color primaryGreen) {
    final isSelected = _activeFilter == code;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = code;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6F4EE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryGreen : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? primaryGreen : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. PLANS VIEW (Matching Image 3)
// -----------------------------------------------------------------------------
class PlansScreenView extends StatefulWidget {
  const PlansScreenView({super.key});

  @override
  State<PlansScreenView> createState() => _PlansScreenViewState();
}

class _PlansScreenViewState extends State<PlansScreenView> {
  bool _isLoading = true;
  List<dynamic> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await ApiService.fetchPlans();
      if (mounted) {
        setState(() {
          _plans = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _plans = [];
          _isLoading = false;
        });
      }
    }
  }

  void _openAddPlanDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();
    int durationDays = 30;
    int frequencyMonths = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.assignment_add, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Add New Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Plan Name *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. Standard Shop / Gym Monthly',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Price (₹) *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'e.g. 18500',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Duration (Days)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: durationDays,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 Days')),
                    DropdownMenuItem(value: 60, child: Text('60 Days')),
                    DropdownMenuItem(value: 90, child: Text('90 Days')),
                    DropdownMenuItem(value: 365, child: Text('1 Year (365 Days)')),
                  ],
                  onChanged: (val) => setDialogState(() => durationDays = val ?? 30),
                ),
                const SizedBox(height: 14),
                const Text('Billing Frequency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: frequencyMonths,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Monthly (1 Month)')),
                    DropdownMenuItem(value: 3, child: Text('Quarterly (3 Months)')),
                    DropdownMenuItem(value: 6, child: Text('Half-Yearly (6 Months)')),
                    DropdownMenuItem(value: 12, child: Text('Yearly (12 Months)')),
                  ],
                  onChanged: (val) => setDialogState(() => frequencyMonths = val ?? 1),
                ),
                const SizedBox(height: 14),
                const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. Standard shop unit on ground floor',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final priceText = priceController.text.trim();
                if (name.isEmpty || priceText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Plan name and Price')),
                  );
                  return;
                }
                final price = double.tryParse(priceText) ?? 0.0;
                final success = await ApiService.createPlan({
                  'name': name,
                  'price': price,
                  'durationDays': durationDays,
                  'frequencyMonths': frequencyMonths,
                  'description': descriptionController.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan created successfully!'), backgroundColor: Color(0xFF059669)),
                    );
                    _loadPlans();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create plan. Please check backend connection.'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text('Create Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF059669);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Plans',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddPlanDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  'Add new plan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: primaryGreen)))
          else if (_plans.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text(
                    'No Plans Found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap "Add new plan" above to create your first membership or rent plan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text('Add new plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _openAddPlanDialog,
                  ),
                ],
              ),
            )
          else
            ..._plans.map((plan) {
              final name = plan['name'] ?? 'Plan';
              final price = (plan['price'] as num?)?.toInt() ?? 0;
              final membersCount = plan['totalMembers'] ?? plan['membersCount'] ?? 0;
              final isActive = plan['isActive'] ?? true;
              final billing = plan['billing'] ?? '${plan['durationDays'] ?? 30} Days billing';

              final groupsCount = plan['groupsCount'] ?? (plan['groups'] as List?)?.length ?? 0;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanDetailScreen(plan: plan),
                    ),
                  ).then((_) => _loadPlans());
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
                                child: const Icon(
                                  Icons.assignment_outlined,
                                  size: 20,
                                  color: primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    billing,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isActive ? const Color(0xFF166534) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.people_outline_rounded,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$membersCount members',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (groupsCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$groupsCount groups',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAF9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. EXPENSES VIEW (Matching Image 4)
// -----------------------------------------------------------------------------
class ExpensesScreenView extends StatefulWidget {
  const ExpensesScreenView({super.key});

  @override
  State<ExpensesScreenView> createState() => _ExpensesScreenViewState();
}

class _ExpensesScreenViewState extends State<ExpensesScreenView> {
  bool _isLoading = true;
  List<dynamic> _expenses = [];
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await ApiService.fetchExpenses();
      final cats = await ApiService.fetchExpenseCategories();
      if (mounted) {
        setState(() {
          _expenses = fetched;
          _categories = cats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openAddExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String? selectedCategoryId = _categories.isNotEmpty ? _categories.first['id']?.toString() : null;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Color(0xFFF97316)),
              SizedBox(width: 8),
              Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Expense Title *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Electricity Bill, Rent, Salaries',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Amount (₹) *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'e.g. 5000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF059669)),
                      label: const Text('New Category', style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                      onPressed: () => _openAddCategoryDialog(onAdded: (newCatId) {
                        _loadExpenses().then((_) {
                          setDialogState(() {
                            selectedCategoryId = newCatId;
                          });
                        });
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCategoryId,
                      hint: const Text('Select or add category'),
                      items: _categories.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['id'].toString(),
                          child: Text(c['name'] ?? 'Category'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (title.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter title and valid amount')),
                  );
                  return;
                }
                final success = await ApiService.createExpense({
                  'title': title,
                  'amount': amount,
                  'categoryId': selectedCategoryId,
                  'expenseDate': selectedDate.toIso8601String(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense added successfully!'), backgroundColor: Color(0xFF059669)),
                    );
                    _loadExpenses();
                  }
                }
              },
              child: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddCategoryDialog({required Function(String newId) onAdded}) {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Expense Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: catController,
          decoration: InputDecoration(
            hintText: 'e.g. Maintenance, WiFi, Tea & Snacks',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () async {
              final name = catController.text.trim();
              if (name.isNotEmpty) {
                final success = await ApiService.createExpenseCategory(name);
                if (ctx.mounted) Navigator.pop(ctx);
                if (success && mounted) {
                  final cats = await ApiService.fetchExpenseCategories();
                  final newly = cats.firstWhere((c) => c['name'] == name, orElse: () => cats.isNotEmpty ? cats.last : null);
                  if (newly != null) {
                    onAdded(newly['id'].toString());
                  }
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpenseItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('Are you sure you want to delete this expense record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteExpense(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted')));
        _loadExpenses();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF059669);

    double totalExp = 0;
    final Map<String, double> categoryTotals = {};
    for (var e in _expenses) {
      final amt = (e['amount'] as num?)?.toDouble() ?? 0.0;
      totalExp += amt;
      final catName = e['category']?['name'] ?? 'General';
      categoryTotals[catName] = (categoryTotals[catName] ?? 0) + amt;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Expenses',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddExpenseDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  'Add expense',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Expenses Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'TOTAL EXPENSES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${totalExp.toInt()}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_expenses.length} records recorded',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category Breakdown chips
          if (categoryTotals.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category Breakdown',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categoryTotals.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                            const SizedBox(width: 6),
                            Text('₹${entry.value.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFF97316))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Month's Expense List Section
          const Text(
            "Expense Records",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: primaryGreen)))
          else if (_expenses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text('No expenses recorded yet', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  SizedBox(height: 4),
                  Text('Tap "Add expense" above to record gym/facility expenses.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            )
          else
            ..._expenses.map((exp) {
              final catName = exp['category']?['name'] ?? 'General';
              final date = exp['expenseDate'] != null
                  ? DateTime.parse(exp['expenseDate'].toString()).toString().split(' ')[0]
                  : '';
              final id = exp['id']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_rounded, color: Color(0xFFF97316), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exp['title'] ?? 'Expense',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$catName${date.isNotEmpty ? ' • $date' : ''}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '₹${exp['amount']}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF97316),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                          tooltip: 'Delete',
                          onPressed: () => _deleteExpenseItem(id),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. REPORTS VIEW (Matching Image 5)
// -----------------------------------------------------------------------------
class ReportsScreenView extends StatefulWidget {
  const ReportsScreenView({super.key});

  @override
  State<ReportsScreenView> createState() => _ReportsScreenViewState();
}

class _ReportsScreenViewState extends State<ReportsScreenView> {
  bool _isLoading = true;
  double _income = 0;
  double _expenses = 0;
  double _pending = 0;
  double _collectionRate = 0;
  int _totalMembers = 0;
  int _paidMembersCount = 0;
  int _unpaidMembersCount = 0;
  List<dynamic> _planRevenue = [];
  List<dynamic> _expensesByCategory = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final summaryRes = await ApiService.fetchFinancialSummary();
      if (mounted) {
        final summary = summaryRes['summary'] ?? {};
        setState(() {
          _income = (summary['totalIncome'] as num?)?.toDouble() ?? 0.0;
          _expenses = (summary['totalExpenses'] as num?)?.toDouble() ?? 0.0;
          _pending = (summary['totalPending'] as num?)?.toDouble() ?? 0.0;
          _collectionRate = (summary['collectionRate'] as num?)?.toDouble() ??
              ((_income + _pending) > 0 ? (_income / (_income + _pending)) * 100 : 0.0);
          _totalMembers = summary['totalMembers'] ?? 0;
          _paidMembersCount = summary['paidMembersCount'] ?? 0;
          _unpaidMembersCount = summary['unpaidMembersCount'] ?? 0;
          _planRevenue = summaryRes['planRevenue'] ?? [];
          _expensesByCategory = summaryRes['expensesByCategory'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF059669);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryGreen));
    }

    final netBalance = _income - _expenses;
    final totalExpected = _income + _pending;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Financial Report',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: primaryGreen),
                onPressed: _loadReport,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Collection rate Card (Formula: Collected / Expected * 100)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.insights_rounded, color: primaryGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Collection Rate',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '$_paidMembersCount of $_totalMembers payments collected',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '${_collectionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_collectionRate / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: primaryGreen,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Formula: (₹${_income.toInt()} collected ÷ ₹${totalExpected.toInt()} expected) × 100',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Income and Net Balance Cards
          Row(
            children: [
              // INCOME
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'INCOME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${_income.toInt()}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_paidMembersCount paid',
                        style: const TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // NET BALANCE
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: netBalance >= 0 ? const Color(0xFF3B82F6) : Colors.redAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'NET PROFIT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${netBalance.toInt()}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: netBalance >= 0 ? const Color(0xFF0F172A) : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'After ₹${_expenses.toInt()} exp.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Breakdown Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Status Overview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusRow('Paid Members', '$_paidMembersCount (₹${_income.toInt()})', const Color(0xFF059669)),
                const SizedBox(height: 12),
                _buildStatusRow('Pending Dues', '$_unpaidMembersCount (₹${_pending.toInt()})', const Color(0xFFEF4444)),
                const SizedBox(height: 12),
                _buildStatusRow('Total Expected', '₹${totalExpected.toInt()}', const Color(0xFF6366F1)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Plan Revenue Breakdown
          if (_planRevenue.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                      const Text(
                        'Plan & Group Revenue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${_planRevenue.length} Plans',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._planRevenue.map((p) {
                    final planName = p['name'] ?? 'Plan';
                    final planRev = (p['revenue'] as num?)?.toInt() ?? 0;
                    final membersCount = p['membersCount'] ?? 0;
                    final groups = p['groups'] as List<dynamic>? ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                planName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                '₹$planRev',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: primaryGreen),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$membersCount members enrolled',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (groups.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 8),
                            ...groups.map((g) {
                              final gName = g['name'] ?? 'Group';
                              final gRev = (g['revenue'] as num?)?.toInt() ?? 0;
                              final gMembers = g['members'] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Text('$gName ($gMembers mem)', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                      ],
                                    ),
                                    Text('₹$gRev', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Expenses by Category Breakdown
          if (_expensesByCategory.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expenses by Category',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._expensesByCategory.map((cat) {
                    final catName = cat['category'] ?? 'General';
                    final catTotal = (cat['total'] as num?)?.toInt() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            catName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          Text(
                            '₹$catTotal',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(String title, String count, Color dotColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
        Text(
          count,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
