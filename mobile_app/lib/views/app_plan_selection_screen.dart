import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';

class AppPlanItem {
  final String id;
  final String name;
  final double price;
  final String? tag;
  final String description;
  final int durationMonths;
  final bool isFreeTrial;

  AppPlanItem({
    required this.id,
    required this.name,
    required this.price,
    this.tag,
    required this.description,
    required this.durationMonths,
    required this.isFreeTrial,
  });

  factory AppPlanItem.fromJson(Map<String, dynamic> json) {
    return AppPlanItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      tag: json['tag'],
      description: json['description'] ?? '',
      durationMonths: json['durationMonths'] ?? 1,
      isFreeTrial: json['isFreeTrial'] ?? false,
    );
  }
}

class AppPlanSelectionScreen extends StatefulWidget {
  const AppPlanSelectionScreen({super.key});

  @override
  State<AppPlanSelectionScreen> createState() => _AppPlanSelectionScreenState();
}

class _AppPlanSelectionScreenState extends State<AppPlanSelectionScreen> {
  bool _isLoading = true;
  List<AppPlanItem> _plans = [];
  String _selectedPlanId = '';

  // Fallback plans if backend API is offline or loading
  final List<AppPlanItem> _defaultPlans = [
    AppPlanItem(
      id: 'default_free',
      name: 'Free trial 30 days',
      price: 0,
      tag: 'Default',
      description: 'All features unlocked for one month',
      durationMonths: 1,
      isFreeTrial: true,
    ),
    AppPlanItem(
      id: 'default_plus',
      name: 'Plus',
      price: 399,
      tag: null,
      description: 'All features unlocked for one month',
      durationMonths: 1,
      isFreeTrial: false,
    ),
    AppPlanItem(
      id: 'default_max',
      name: 'Max',
      price: 699,
      tag: null,
      description: 'All features unlocked for three months',
      durationMonths: 3,
      isFreeTrial: false,
    ),
    AppPlanItem(
      id: 'default_max_plus',
      name: 'Max+',
      price: 999,
      tag: 'Popular',
      description: 'All features unlocked for six months',
      durationMonths: 6,
      isFreeTrial: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchAppPlans();
  }

  Future<void> _fetchAppPlans() async {
    setState(() => _isLoading = true);
    try {
      // Try fetching from local backend
      final response = await http
          .get(Uri.parse('http://localhost:5001/api/app-plans'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> list = data['data'] ?? [];
        if (list.isNotEmpty) {
          final fetched = list.map((item) => AppPlanItem.fromJson(item)).toList();
          setState(() {
            _plans = fetched;
            _selectedPlanId = fetched.first.id;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      // Ignore error and use default fallback list
    }

    setState(() {
      _plans = _defaultPlans;
      _selectedPlanId = _defaultPlans.first.id;
      _isLoading = false;
    });
  }

  void _onContinue() {
    final selectedPlan = _plans.firstWhere(
      (p) => p.id == _selectedPlanId,
      orElse: () => _plans.first,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected plan: ${selectedPlan.name} (${selectedPlan.price == 0 ? "Free Trial" : "₹${selectedPlan.price.toInt()}"})'),
        backgroundColor: const Color(0xFF059669),
      ),
    );

    // Navigate to Main App Navigation Screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF8FAF9);
    const primaryGreen = Color(0xFF059669);

    final selectedPlan = _plans.firstWhere(
      (p) => p.id == _selectedPlanId,
      orElse: () => _defaultPlans.first,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Title & Subtitle
              const Text(
                'Choose a plan for your app',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start with the 30 day free trial and upgrade anytime when you are ready.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // Plans list
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryGreen),
                      )
                    : ListView.builder(
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          final plan = _plans[index];
                          final isSelected = plan.id == _selectedPlanId;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPlanId = plan.id;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? primaryGreen : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? primaryGreen.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
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
                                          Text(
                                            plan.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (plan.tag != null && plan.tag!.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: plan.tag == 'Popular'
                                                    ? const Color(0xFFFEF3C7)
                                                    : const Color(0xFFE6F4EE),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                plan.tag!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: plan.tag == 'Popular'
                                                      ? const Color(0xFFD97706)
                                                      : primaryGreen,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? primaryGreen : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? primaryGreen : const Color(0xFFCBD5E1),
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    plan.price == 0 ? 'Free' : '₹${plan.price.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    plan.description,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    selectedPlan.isFreeTrial ? 'Start 30 Day Free Trial' : 'Continue with ${selectedPlan.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
