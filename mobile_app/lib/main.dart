import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'views/add_member_screen.dart';
import 'views/app_plan_selection_screen.dart';
import 'views/member_detail_screen.dart';
import 'views/plan_detail_screen.dart';
import 'views/group_detail_screen.dart';
import 'views/settings_screen.dart';
import 'views/login_screen.dart';
import 'views/profile_completion_screen.dart';
import 'services/api_service.dart';
import 'utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isLoggedIn = await ApiService.isLoggedIn();
  final isProfileComplete = isLoggedIn ? await ApiService.isProfileCompleted() : false;
  final session = isLoggedIn ? await ApiService.getSessionData() : <String, String?>{};

  runApp(RentTrackApp(
    isLoggedIn: isLoggedIn,
    isProfileComplete: isProfileComplete,
    userPhone: session['phone'] ?? '',
    userName: session['userName'],
    orgName: session['orgName'],
  ));
}

class RentTrackApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool isProfileComplete;
  final String userPhone;
  final String? userName;
  final String? orgName;

  const RentTrackApp({
    super.key,
    this.isLoggedIn = false,
    this.isProfileComplete = false,
    this.userPhone = '',
    this.userName,
    this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    Widget initialScreen;
    if (!isLoggedIn) {
      initialScreen = const LoginScreen();
    } else if (!isProfileComplete) {
      initialScreen = ProfileCompletionScreen(
        phone: userPhone,
        initialName: userName,
        initialOrgName: orgName,
      );
    } else {
      initialScreen = const MainNavigationScreen();
    }

    return MaterialApp(
      title: 'RentTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: AppColors.iosBackground,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      home: initialScreen,
    );
  }
}

// Global Apple-Style Dialog when subscription expires
void showSubscriptionExpiredDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.lock_clock_rounded, color: AppColors.appleRed),
          SizedBox(width: 8),
          Text(
            'Subscription Expired',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your account is in View-Only Mode.',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
          ),
          SizedBox(height: 8),
          Text(
            'All existing members, payments, and reports are safely viewable. To add new members, create plans, or record fees, please renew your subscription.\n\nNote: Any unused WhatsApp credits roll over automatically when you renew!',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Stay in View-Only', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppPlanSelectionScreen()),
            );
          },
          child: const Text('Renew / Upgrade Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
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
    return FutureBuilder<Map<String, String?>>(
      future: ApiService.getSessionData(),
      builder: (context, snapshot) {
        final orgName = snapshot.data?['orgName'] ?? 'RentTrack';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  orgName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                    letterSpacing: -0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.onSurfaceVariant),
                            ],
                          ),
                          const Text(
                            'Property Management OS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.workspace_premium_outlined, color: AppColors.primary, size: 22),
                    tooltip: 'Subscription & Credits',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AppPlanSelectionScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppColors.onSurfaceVariant, size: 22),
                    tooltip: 'Settings & Payout',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () => _showLogoutDialog(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
  bool _isSubscriptionExpired = false;
  String _activePlanName = '';

  final List<Widget> _screens = [
    const HomeScreenView(),
    const PlansScreenView(),
    const ExpensesScreenView(),
    const ReportsScreenView(),
  ];

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final sub = await ApiService.fetchSubscriptionCredits();
      if (mounted) {
        setState(() {
          _isSubscriptionExpired = sub['subscription']?['isExpired'] == true;
          _activePlanName = sub['subscription']?['subscriptionName'] ?? '';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF059669);

    return Scaffold(
      backgroundColor: AppColors.iosBackground,
      body: SafeArea(
        child: Column(
          children: [
            const RentTrackHeader(),

            // Persistent Apple-Style View-Only Mode Banner if subscription is expired
            if (_isSubscriptionExpired)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1F2),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFECDD3), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, size: 18, color: AppColors.appleRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _activePlanName.isNotEmpty
                            ? 'View-Only Mode • $_activePlanName Expired'
                            : 'View-Only Mode • Subscription Expired',
                        style: const TextStyle(
                          color: AppColors.appleRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AppPlanSelectionScreen()),
                        );
                        _checkSubscriptionStatus();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.appleRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Renew Plan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
  Map<String, dynamic>? _subscriptionData;

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
      final subData = await ApiService.fetchSubscriptionCredits();

      if (mounted) {
        setState(() {
          _totalCollected = (summaryRes['summary']?['totalIncome'] as num?)?.toDouble() ?? 0.0;
          _totalPending = (summaryRes['summary']?['totalPending'] as num?)?.toDouble() ?? 0.0;
          _allMembers = membersList;
          _subscriptionData = subData;
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
    final sub = await ApiService.fetchSubscriptionCredits();
    if (sub['subscription']?['isExpired'] == true) {
      if (mounted) showSubscriptionExpiredDialog(context);
      return;
    }

    final available = sub['credits']?['availableCredits'] ?? 0;
    if (available <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient WhatsApp credits. Please top-up in Settings.'),
            backgroundColor: AppColors.appleAmber,
          ),
        );
      }
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent('Hi $name, this is a friendly reminder regarding your pending fee of ₹$amount. Please clear it at your earliest convenience.');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openAddMember() async {
    final sub = await ApiService.fetchSubscriptionCredits();
    if (!mounted) return;
    if (sub['subscription']?['isExpired'] == true) {
      showSubscriptionExpiredDialog(context);
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMemberScreen()),
    );
    if (!mounted) return;
    if (result == true) {
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paidMembers = _allMembers.where((m) => m['status'] == 'PAID').toList();
    final unpaidMembers = _allMembers.where((m) => m['status'] == 'UNPAID').toList();
    final frozenMembers = _allMembers.where((m) => m['status'] == 'FROZEN').toList();
    final overdueMembers = unpaidMembers;

    final totalTarget = _totalCollected + _totalPending;
    final percentCollected = totalTarget > 0 ? ((_totalCollected / totalTarget) * 100).toInt() : 100;

    List<dynamic> displayedMembers = _allMembers;
    if (_activeFilter == 'PAID') displayedMembers = paidMembers;
    if (_activeFilter == 'UNPAID') displayedMembers = unpaidMembers;
    if (_activeFilter == 'OVERDUE') displayedMembers = overdueMembers;
    if (_activeFilter == 'FROZEN') displayedMembers = frozenMembers;

    final subName = _subscriptionData?['subscription']?['subscriptionName'] ?? 'Active Plan';
    final isTrial = subName.toLowerCase().contains('trial');

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Subscription Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          subName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isTrial ? '• 2-Days Trial Mode' : '• Active Plan',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AppPlanSelectionScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor: AppColors.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2x2 Metric KPI Bento Grid
            Row(
              children: [
                // Card 1: Active Members
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
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
                            const Text(
                              'Active Members',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceContainer,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.group_outlined, size: 16, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_allMembers.length}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              '+${_allMembers.length} active',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Card 2: Collected
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
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
                            const Text(
                              'Collected',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.payments_outlined, size: 16, color: AppColors.secondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${_totalCollected.toInt()}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.trending_up_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              '$percentCollected% of target',
                              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                            ),
                          ],
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
                // Card 3: Pending Dues
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
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
                            const Text(
                              'Pending Dues',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.errorContainer.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.pending_actions_rounded, size: 16, color: AppColors.error),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${_totalPending.toInt()}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.error),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${unpaidMembers.length} members unpaid',
                          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Card 4: Overdue
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
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
                            const Text(
                              'Overdue',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: AppColors.appleAmberBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.appleAmber),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${overdueMembers.length}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                            ),
                            const SizedBox(width: 6),
                            if (overdueMembers.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.appleAmberBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Action Needed',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.appleAmber),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          overdueMembers.isEmpty ? 'All dues up to date' : 'Immediate attention',
                          style: TextStyle(
                            fontSize: 11,
                            color: overdueMembers.isEmpty ? AppColors.primary : AppColors.appleAmber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Filter Segmented Control (Stitch Pills)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStitchFilterPill('All', _allMembers.length, 'ALL'),
                  const SizedBox(width: 8),
                  _buildStitchFilterPill('Paid', paidMembers.length, 'PAID'),
                  const SizedBox(width: 8),
                  _buildStitchFilterPill('Pending', unpaidMembers.length, 'UNPAID'),
                  const SizedBox(width: 8),
                  _buildStitchFilterPill('Overdue', overdueMembers.length, 'OVERDUE'),
                  const SizedBox(width: 8),
                  _buildStitchFilterPill('Frozen ❄️', frozenMembers.length, 'FROZEN'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Member Roster Header & Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${displayedMembers.length} Residents & Members',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openAddMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Members List or Empty State
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (displayedMembers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded, size: 28, color: AppColors.outline),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No members found',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap "Add Member" above to onboard your first resident or customer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              ...displayedMembers.map((m) {
                final name = m['fullName'] ?? 'Member';
                final phone = m['phone'] ?? '';
                final status = m['status'] ?? 'PAID';
                final amount = (m['amount'] as num?)?.toDouble() ?? (m['plan']?['price'] as num?)?.toDouble() ?? 0.0;
                final planName = m['plan']?['name'] ?? m['group']?['name'] ?? 'Plan';
                final isPaid = status == 'PAID';
                final isFrozen = status == 'FROZEN';

                // Compute initials
                final parts = name.trim().split(' ');
                final initials = parts.length > 1
                    ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                    : name.isNotEmpty ? name[0].toUpperCase() : 'M';

                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MemberDetailScreen(member: m)),
                    );
                    _loadDashboardData();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar with Initials
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Name, Subtitle, Phone
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          planName,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                                        ),
                                      ),
                                      if (phone.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          phone,
                                          style: const TextStyle(fontSize: 11, color: AppColors.outline),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Amount & Status Badge
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${amount.toInt()}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isPaid ? AppColors.primary : AppColors.error,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPaid
                                        ? AppColors.appleGreenBg
                                        : isFrozen
                                            ? AppColors.surfaceContainer
                                            : AppColors.appleRedBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isPaid
                                          ? AppColors.primary
                                          : isFrozen
                                              ? AppColors.onSurfaceVariant
                                              : AppColors.appleRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Quick Action Footer (Call & WhatsApp)
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.surfaceContainer),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final uri = Uri.parse('tel:$phone');
                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone_outlined, size: 13, color: AppColors.onSurfaceVariant),
                                      SizedBox(width: 4),
                                      Text(
                                        'Call',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _sendWhatsAppReminder(phone, name, amount),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat_outlined, size: 13, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'WhatsApp',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStitchFilterPill(String label, int count, String code) {
    final isSelected = _activeFilter == code;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
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

  void _openAddPlanDialog() async {
    final sub = await ApiService.fetchSubscriptionCredits();
    if (!mounted) return;
    if (sub['subscription']?['isExpired'] == true) {
      showSubscriptionExpiredDialog(context);
      return;
    }

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

  String _selectedPlanFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF006948);
    const secondaryContainer = Color(0xFF6CF8BB);

    // Dynamic calculations from real plans data
    final activePlans = _plans.where((p) => p['isActive'] != false).toList();
    final inactivePlans = _plans.where((p) => p['isActive'] == false).toList();

    int totalRooms = 0;
    int totalOccupiedBeds = 0;
    int totalCapacityBeds = 0;
    double monthlyRunTotal = 0.0;

    for (var p in _plans) {
      final price = (p['price'] as num?)?.toDouble() ?? 0.0;
      final int members = ((p['totalMembers'] ?? p['membersCount']) as num?)?.toInt() ?? 0;
      final groups = (p['groups'] as List?) ?? [];
      final int gCount = (p['groupsCount'] as num?)?.toInt() ?? groups.length;
      totalRooms += gCount;
      totalOccupiedBeds += members;

      int planCap = 0;
      for (var g in groups) {
        final int cap = (g['capacity'] as num?)?.toInt() ?? 0;
        planCap += cap;
      }
      totalCapacityBeds += (planCap > members ? planCap : members);
      monthlyRunTotal += (price * members);
    }

    if (totalCapacityBeds < totalOccupiedBeds) totalCapacityBeds = totalOccupiedBeds;
    final occupancyPercent = totalCapacityBeds > 0
        ? ((totalOccupiedBeds / totalCapacityBeds) * 100).round()
        : 0;
    final availableBeds = (totalCapacityBeds - totalOccupiedBeds).clamp(0, 999999);

    final filteredPlans = _selectedPlanFilter == 'ACTIVE'
        ? activePlans
        : _selectedPlanFilter == 'INACTIVE'
            ? inactivePlans
            : _plans;

    return RefreshIndicator(
      onRefresh: _loadPlans,
      color: primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header & Top Action (Matching Stitch plans_batches.html)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plans & Rooms',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF191C1E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Configure tariffs, batches & bed allocations',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF3D4A42),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openAddPlanDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text(
                    'New Plan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Overall Capacity & KPI Summary Card (Stitch design)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 8,
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
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.analytics_outlined,
                              size: 18,
                              color: Color(0xFF00714D),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Campus Occupancy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF191C1E),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF85F8C4).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '$occupancyPercent% Full',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9999),
                    child: Container(
                      height: 10,
                      width: double.infinity,
                      color: const Color(0xFFE0E3E5),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (occupancyPercent / 100.0).clamp(0.0, 1.0),
                        child: Container(color: primaryGreen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$totalOccupiedBeds Beds Occupied',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3D4A42),
                        ),
                      ),
                      Text(
                        '$availableBeds Beds Available',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF191C1E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Quick Micro Stats Strip
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${activePlans.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF191C1E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Active Plans',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF3D4A42),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$totalRooms',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF191C1E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Total Rooms',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF3D4A42),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                monthlyRunTotal >= 100000
                                    ? '₹${(monthlyRunTotal / 100000).toStringAsFixed(1)}L'
                                    : '₹${(monthlyRunTotal / 1000).toStringAsFixed(0)}K',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Monthly Run',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF3D4A42),
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
            const SizedBox(height: 14),

            // Stitch Segmented Filter Control
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEEF0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All Plans (${_plans.length})'),
                    _buildFilterChip('ACTIVE', 'Active (${activePlans.length})'),
                    _buildFilterChip('INACTIVE', 'Inactive (${inactivePlans.length})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator(color: primaryGreen)),
              )
            else if (_plans.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.assignment_outlined, size: 28, color: Color(0xFF6D7A72)),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No Plans Created Yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF191C1E)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap "New Plan" above to configure rent tariffs and allocate member rooms.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF3D4A42)),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: const Text('Create First Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      onPressed: _openAddPlanDialog,
                    ),
                  ],
                ),
              )
            else
              ...filteredPlans.map((plan) {
                final name = plan['name'] ?? 'Plan';
                final price = (plan['price'] as num?)?.toInt() ?? 0;
                final membersCount = (plan['totalMembers'] ?? plan['membersCount'] as num?)?.toInt() ?? 0;
                final isActive = plan['isActive'] ?? true;
                final durationDays = plan['durationDays'] ?? 30;
                final groups = (plan['groups'] as List?) ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlanDetailScreen(plan: plan),
                          ),
                        ).then((_) => _loadPlans());
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Plan Card Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isActive ? primaryGreen : const Color(0xFF6D7A72),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF191C1E),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '₹${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: primaryGreen,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '/ ${durationDays}d per bed',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF3D4A42),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFF85F8C4).withValues(alpha: 0.3) : const Color(0xFFECEEF0),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    isActive ? 'ACTIVE' : 'INACTIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isActive ? primaryGreen : const Color(0xFF3D4A42),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Cycle Meta Pills (Stitch design)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F6),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.event_repeat, size: 13, color: Color(0xFF3D4A42)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Cycle: $durationDays Days',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3D4A42)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: secondaryContainer.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat_bubble_outline, size: 13, color: Color(0xFF00714D)),
                                      SizedBox(width: 4),
                                      Text(
                                        'WhatsApp Due -3d',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF00714D)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F6),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    '$membersCount Members',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3D4A42)),
                                  ),
                                ),
                              ],
                            ),

                            // Sub-rooms / Batches accordion (if groups exist)
                            if (groups.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFECEEF0)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Assigned Rooms (${groups.length} Rooms)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF191C1E),
                                    ),
                                  ),
                                  const Text(
                                    'View all →',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Mini room chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: groups.take(4).map((g) {
                                  final gName = g['name'] ?? 'Room';
                                  final gCap = g['capacity'] != null ? '${g['capacity']} beds' : 'Standard';
                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => GroupDetailScreen(
                                            group: {
                                              ...g,
                                              'planName': name,
                                            },
                                            onUpdate: _loadPlans,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.meeting_room_outlined, size: 14, color: primaryGreen),
                                          const SizedBox(width: 4),
                                          Text(
                                            gName,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF191C1E)),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '• $gCap',
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF3D4A42)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedPlanFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF191C1E) : const Color(0xFF3D4A42),
          ),
        ),
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

  void _openAddExpenseDialog() async {
    final sub = await ApiService.fetchSubscriptionCredits();
    if (!mounted) return;
    if (sub['subscription']?['isExpired'] == true) {
      showSubscriptionExpiredDialog(context);
      return;
    }

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

    return RefreshIndicator(
      onRefresh: _loadExpenses,
      color: primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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

    return RefreshIndicator(
      onRefresh: _loadReport,
      color: primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
