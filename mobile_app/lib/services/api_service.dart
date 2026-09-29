import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // MED-07 FIX: Production URL is first. LAN IPs are development-only fallbacks.
  // Change the production URL below when deploying to your server.
  static const String _productionUrl = 'https://trackmyrent.anandhu-kannan.in/api';
  static const List<String> _candidateHosts = [
    _productionUrl,
    // Development fallbacks (LAN / emulator)
    'http://localhost:5001/api',
    'http://10.0.2.2:5001/api',    // Android emulator → host machine
    'http://192.168.1.7:5001/api',
    'http://192.168.1.4:5001/api',
    'http://192.168.1.2:5001/api',
    'http://192.168.1.3:5001/api',
    'http://192.168.1.5:5001/api',
  ];

  static String _activeBaseUrl = _productionUrl;
  static String get baseUrl => _activeBaseUrl;
  static const String _fallbackOrgId = 'f1aac5fa-5087-41fd-9c13-e9f4b20eae81';

  // ─── Session Management ─────────────────────────────────────────────────────

  static Future<void> saveSession({
    required String token,
    required String role,
    String? orgId,
    String? orgName,
    String? userName,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('renttrack_token', token);
    await prefs.setString('renttrack_role', role);
    if (orgId != null) await prefs.setString('renttrack_org_id', orgId);
    if (orgName != null) await prefs.setString('renttrack_org_name', orgName);
    if (userName != null) await prefs.setString('renttrack_user_name', userName);
    if (phone != null) await prefs.setString('renttrack_phone', phone);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('renttrack_token');
  }

  static Future<Map<String, String?>> getSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString('renttrack_token'),
      'role': prefs.getString('renttrack_role'),
      'orgId': prefs.getString('renttrack_org_id'),
      'orgName': prefs.getString('renttrack_org_name'),
      'userName': prefs.getString('renttrack_user_name'),
      'phone': prefs.getString('renttrack_phone'),
    };
  }

  static Future<bool> isProfileCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('renttrack_user_name');
    final orgName = prefs.getString('renttrack_org_name');
    
    // Both user name and facility name must be set, non-empty, and not generic placeholders
    if (userName == null || userName.trim().isEmpty || userName.trim() == 'Property Owner') return false;
    if (orgName == null || orgName.trim().isEmpty || orgName.trim() == 'My Facility') return false;
    return true;
  }

  static Future<void> markProfileCompleted({
    required String userName,
    required String orgName,
    String? planId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('renttrack_user_name', userName);
    await prefs.setString('renttrack_org_name', orgName);
    await prefs.setBool('renttrack_plan_chosen', true);
    if (planId != null) await prefs.setString('renttrack_chosen_plan_id', planId);
  }

  static Future<String> getOrgId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('renttrack_org_id') ?? _fallbackOrgId;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('renttrack_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Auth ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> checkPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http
            .get(Uri.parse('$host/auth/check-phone/$cleaned'))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data;
        }
      } catch (_) {}
    }
    return {'exists': false};
  }

  static Future<Map<String, dynamic>> sendOtp(String phone, {String? mode}) async {
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.post(
          Uri.parse('$host/auth/send-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': phone,
            if (mode != null) 'mode': mode,
          }),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['alreadyRegistered'] != true) {
            data['success'] = true;
          }
          return data;
        }
      } catch (_) {}
    }

    // Offline fallback — only available in debug mode
    // In release builds this returns an error instead of exposing OTP.
    assert(() {
      // This block runs only in debug/dev builds
      return true;
    }());
    return {
      'success': false,
      'error': 'Unable to connect to TrackMyRent server. Please check your internet connection.',
    };
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String? orgName,
    String? adminName,
    String? orgType,
    String? email,
  }) async {
    final trimmed = otp.trim();

    // 1. Try online verification across candidate hosts
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.post(
          Uri.parse('$host/auth/verify-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': phone,
            'otp': trimmed,
            if (orgName != null && orgName.isNotEmpty) 'orgName': orgName,
            if (adminName != null && adminName.isNotEmpty) 'adminName': adminName,
            if (orgType != null && orgType.isNotEmpty) 'orgType': orgType,
            if (email != null && email.isNotEmpty) 'email': email,
          }),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          data['success'] = true;
          return data;
        }
      } catch (_) {}
    }

    // BUG-FIX BUG-04: Demo mode only available in debug builds, never in release/production.
    // In debug mode, demo OTPs (00000, 123456) allow local testing without a server.
    bool isDebugMode = false;
    assert(() { isDebugMode = true; return true; }());

    if (isDebugMode && (trimmed == '00000' || trimmed == '0000' || trimmed == '000000' || trimmed == '123456')) {
      return {
        'message': 'Demo Login Successful (Debug Mode)',
        'token': 'demo_token_${DateTime.now().millisecondsSinceEpoch}',
        'user': {
          'id': 'demo_admin_user',
          'name': (adminName != null && adminName.isNotEmpty) ? adminName : 'Demo Facility Admin',
          'phone': phone,
          'role': 'ORG_ADMIN',
        },
        'organization': {
          'id': _fallbackOrgId,
          'name': (orgName != null && orgName.isNotEmpty) ? orgName : 'RentTrack Demo Facility',
          'type': orgType ?? 'GYM',
        },
      };
    }

    return {'error': 'Unable to verify OTP. Please check your connection and try again.'};
  }

  static Future<List<dynamic>> fetchOrganizations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/auth/organizations'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['organizations'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ─── Reports ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchFinancialSummary() async {
    final orgId = await getOrgId();
    final response = await http.get(Uri.parse('$baseUrl/reports/summary?organizationId=$orgId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load financial summary');
  }

  // ─── Members ────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchMembers({String? status, String? month, String? year}) async {
    final orgId = await getOrgId();
    String url = '$baseUrl/members?organizationId=$orgId';
    if (status != null) url += '&status=$status';
    if (month != null) url += '&month=$month';
    if (year != null) url += '&year=$year';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['members'] ?? [];
    }
    throw Exception('Failed to load members');
  }

  static Future<Map<String, dynamic>> fetchMemberDetails(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/members/$id'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load member details');
  }

  static Future<Map<String, dynamic>> fetchMemberSchedules(String memberId) async {
    final response = await http.get(Uri.parse('$baseUrl/payments/schedules/$memberId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  // MED-03/MED-04 FIX: Returns full response map including transactionId and whatsappReceiptSent
  // so the UI can display accurate receipt info and pass real IDs to the dialog.
  static Future<Map<String, dynamic>> markAsPaid(String scheduleId, double amountPaid,
      {String paymentMethod = 'CASH', String? notes}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/mark-paid'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'scheduleId': scheduleId,
          'amountPaid': amountPaid,
          'paymentMethod': paymentMethod,
          'notes': notes,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }
      return {'success': false, 'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> markAsUnpaid(String scheduleId, {bool confirmed = false}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/mark-unpaid'),
      headers: await _authHeaders(),
      body: jsonEncode({'scheduleId': scheduleId, 'confirmed': confirmed}),
    );
    return jsonDecode(response.body);
  }

  static Future<bool> freezeMonth(String scheduleId, {String? notes}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/freeze'),
      headers: await _authHeaders(),
      body: jsonEncode({'scheduleId': scheduleId, 'notes': notes ?? 'Month frozen by admin'}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> unfreezeMonth(String scheduleId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/unfreeze'),
      headers: await _authHeaders(),
      body: jsonEncode({'scheduleId': scheduleId}),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> createRazorpayOrder(
      String scheduleId, String memberId, double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/razorpay/create-order'),
      headers: await _authHeaders(),
      body: jsonEncode({'scheduleId': scheduleId, 'memberId': memberId, 'amount': amount}),
    );
    return jsonDecode(response.body);
  }

  static Future<bool> createMember(Map<String, dynamic> memberData) async {
    final orgId = await getOrgId();
    final response = await http.post(
      Uri.parse('$baseUrl/members'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'organizationId': orgId, ...memberData}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> updateMember(String id, Map<String, dynamic> memberData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/members/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(memberData),
    );
    return response.statusCode == 200;
  }

  // ─── Plans ──────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchPlans() async {
    final orgId = await getOrgId();
    final response = await http.get(Uri.parse('$baseUrl/plans?organizationId=$orgId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['plans'] ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>> fetchPlanDetail(String planId) async {
    final response = await http.get(Uri.parse('$baseUrl/plans/$planId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load plan detail');
  }

  static Future<Map<String, dynamic>> fetchGroupDetail(String groupId) async {
    final response = await http.get(Uri.parse('$baseUrl/plans/groups/$groupId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load group detail');
  }

  static Future<bool> createPlan(Map<String, dynamic> planData) async {
    try {
      final orgId = await getOrgId();
      final response = await http.post(
        Uri.parse('$baseUrl/plans'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'organizationId': orgId, ...planData}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> createGroup(String planId, String name, {String? schedule, int? capacity}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/plans/groups'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'planId': planId, 'name': name, 'schedule': schedule, 'capacity': capacity}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> deletePlan(String planId) async {
    final response = await http.delete(Uri.parse('$baseUrl/plans/$planId'));
    return response.statusCode == 200;
  }

  // ─── Custom Fields ──────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchCustomFields() async {
    final orgId = await getOrgId();
    final response =
        await http.get(Uri.parse('$baseUrl/plans/custom-fields?organizationId=$orgId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['fields'] ?? [];
    }
    return [];
  }

  static Future<bool> createCustomField({
    required String fieldName,
    required String fieldType,
    List<String> options = const [],
    bool isRequired = false,
  }) async {
    final orgId = await getOrgId();
    String normalized = fieldType.toUpperCase().trim();
    if (normalized == 'BOOLEAN') normalized = 'CHECKBOX';
    if (!['TEXT', 'NUMBER', 'DATE', 'DROPDOWN', 'CHECKBOX', 'MULTI_LINE'].contains(normalized)) {
      normalized = 'TEXT';
    }

    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.post(
          Uri.parse('$host/members/custom-fields'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'organizationId': orgId,
            'fieldName': fieldName,
            'fieldType': normalized,
            'options': options,
            'isRequired': isRequired,
          }),
        ).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200 || response.statusCode == 201) {
          _activeBaseUrl = host;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  static Future<bool> deleteCustomField(String id) async {
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http
            .delete(Uri.parse('$host/plans/custom-fields/$id'))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  // ─── Expenses ───────────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchExpenses() async {
    final orgId = await getOrgId();
    final response = await http.get(Uri.parse('$baseUrl/expenses?organizationId=$orgId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['expenses'] ?? [];
    }
    return [];
  }

  static Future<bool> createExpense(Map<String, dynamic> expenseData) async {
    final orgId = await getOrgId();
    final response = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'organizationId': orgId, ...expenseData}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> deleteExpense(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/expenses/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateExpense(String id, Map<String, dynamic> expenseData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/expenses/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(expenseData),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> fetchExpenseCategories() async {
    final orgId = await getOrgId();
    final response =
        await http.get(Uri.parse('$baseUrl/expenses/categories?organizationId=$orgId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['categories'] ?? [];
    }
    return [];
  }

  static Future<bool> createExpenseCategory(String name) async {
    final orgId = await getOrgId();
    final response = await http.post(
      Uri.parse('$baseUrl/expenses/categories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'organizationId': orgId, 'name': name}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> deleteExpenseCategory(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/expenses/categories/$id'));
    return response.statusCode == 200;
  }

  // ─── WhatsApp Templates ─────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchWhatsAppTemplates() async {
    final orgId = await getOrgId();
    final response = await http
        .get(Uri.parse('$baseUrl/settings/whatsapp-templates?organizationId=$orgId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['templates'] ?? [];
    }
    return [];
  }

  static Future<bool> updateWhatsAppTemplate(String id, String messageText) async {
    final response = await http.put(
      Uri.parse('$baseUrl/settings/whatsapp-templates/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'messageText': messageText}),
    );
    return response.statusCode == 200;
  }

  // ─── Tenant Payout & Subscription ──────────────────────────────────────────

  static Future<bool> updateTenantProfile({
    required String adminName,
    required String orgName,
  }) async {
    final orgId = await getOrgId();
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.put(
          Uri.parse('$host/auth/organization/$orgId/profile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'adminName': adminName,
            'orgName': orgName,
          }),
        ).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('renttrack_org_name', orgName);
          await prefs.setString('renttrack_user_name', adminName);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  static Future<bool> updateTenantPayout(Map<String, dynamic> payoutData) async {
    final orgId = await getOrgId();
    if (orgId.isEmpty) return false;

    // Cache locally immediately so UI state persists even offline
    try {
      final prefs = await SharedPreferences.getInstance();
      if (payoutData.containsKey('bankUpiId')) {
        await prefs.setString('renttrack_bank_upi_id', payoutData['bankUpiId']?.toString() ?? '');
      }
      if (payoutData.containsKey('bankAccountNumber')) {
        await prefs.setString('renttrack_bank_acc_num', payoutData['bankAccountNumber']?.toString() ?? '');
      }
      if (payoutData.containsKey('bankIfsc')) {
        await prefs.setString('renttrack_bank_ifsc', payoutData['bankIfsc']?.toString() ?? '');
      }
      if (payoutData.containsKey('bankAccountName')) {
        await prefs.setString('renttrack_bank_acc_name', payoutData['bankAccountName']?.toString() ?? '');
      }
    } catch (_) {}

    final authHeaders = await _authHeaders();
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http
            .put(
              Uri.parse('$host/auth/organization/$orgId/payout'),
              headers: authHeaders,
              body: jsonEncode(payoutData),
            )
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  static Future<Map<String, String?>> fetchTenantPayout() async {
    final prefs = await SharedPreferences.getInstance();
    final localData = {
      'bankUpiId': prefs.getString('renttrack_bank_upi_id'),
      'bankAccountNumber': prefs.getString('renttrack_bank_acc_num'),
      'bankIfsc': prefs.getString('renttrack_bank_ifsc'),
      'bankAccountName': prefs.getString('renttrack_bank_acc_name'),
    };

    final orgId = await getOrgId();
    if (orgId.isEmpty) return localData;

    final authHeaders = await _authHeaders();
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http
            .get(
              Uri.parse('$host/auth/organization/$orgId'),
              headers: authHeaders,
            )
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['organization'] != null) {
            final org = data['organization'];
            final upi = org['bankUpiId']?.toString();
            final accNum = org['bankAccountNumber']?.toString();
            final ifsc = org['bankIfsc']?.toString();
            final accName = org['bankAccountName']?.toString();

            if (upi != null) await prefs.setString('renttrack_bank_upi_id', upi);
            if (accNum != null) await prefs.setString('renttrack_bank_acc_num', accNum);
            if (ifsc != null) await prefs.setString('renttrack_bank_ifsc', ifsc);
            if (accName != null) await prefs.setString('renttrack_bank_acc_name', accName);

            return {
              'bankUpiId': upi ?? localData['bankUpiId'],
              'bankAccountNumber': accNum ?? localData['bankAccountNumber'],
              'bankIfsc': ifsc ?? localData['bankIfsc'],
              'bankAccountName': accName ?? localData['bankAccountName'],
            };
          }
        }
      } catch (_) {}
    }

    return localData;
  }

  static const List<Map<String, dynamic>> fallbackPlans = [
    {
      'id': 'plan_2_days_trial',
      'name': '2 Days Free Trial',
      'price': 0.0,
      'tag': 'Free 2 Days',
      'description': 'Full feature access for 2 days with 50 starter WhatsApp credits',
      'durationMonths': 0,
      'durationDays': 2,
      'whatsappCredits': 50,
      'isFreeTrial': true,
      'isActive': true,
    },
  ];

  static Future<List<dynamic>> fetchAppPlans() async {
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http
            .get(Uri.parse('$host/app-plans'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          final data = jsonDecode(response.body);
          final list = data['data'] as List<dynamic>?;
          if (list != null) {
            // Filter only active packages created by the admin
            final activeAdminPlans = list.where((p) => p['isActive'] != false).toList();
            if (activeAdminPlans.isNotEmpty) {
              // Admin has created packages! Return 2 Days Free Trial + admin-created packages
              final hasTrial = activeAdminPlans.any((p) =>
                  (p['isFreeTrial'] == true) ||
                  (p['name'] ?? '').toString().toLowerCase().contains('trial') ||
                  (p['name'] ?? '').toString().toLowerCase().contains('2 day'));
              if (!hasTrial) {
                return [fallbackPlans[0], ...activeAdminPlans];
              }
              return activeAdminPlans;
            }
          }
        }
      } catch (_) {}
    }
    // Admin has not set any subscription package yet -> return ONLY the 2 Days Free Trial!
    return fallbackPlans;
  }

  static const List<Map<String, dynamic>> defaultCreditPackages = [
    {
      'id': 'pkg_100_credits',
      'name': '100 Credits Top-Up',
      'credits': 100,
      'price': 99,
      'description': 'Instant top-up for WhatsApp payment reminders & receipts',
      'tag': 'Starter',
      'isActive': true,
    },
    {
      'id': 'pkg_250_credits',
      'name': '250 Credits Top-Up',
      'credits': 250,
      'price': 199,
      'description': 'Standard pack for monthly reminders and receipts',
      'tag': 'Popular',
      'isActive': true,
    },
    {
      'id': 'pkg_500_credits',
      'name': '500 Credits Top-Up',
      'credits': 500,
      'price': 349,
      'description': 'High-volume booster with maximum savings',
      'tag': 'Best Value',
      'isActive': true,
    },
    {
      'id': 'pkg_1000_credits',
      'name': '1000 Credits Mega Pack',
      'credits': 1000,
      'price': 599,
      'description': 'Pro enterprise pack for high-member facilities',
      'tag': 'Pro',
      'isActive': true,
    },
  ];

  static Future<List<dynamic>> fetchCreditPackages() async {
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http
            .get(Uri.parse('$host/credit-packages'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          final data = jsonDecode(response.body);
          final list = data['data'] as List<dynamic>?;
          if (list != null && list.isNotEmpty) {
            return list;
          }
        }
      } catch (_) {}
    }
    return defaultCreditPackages;
  }

  static Future<Map<String, dynamic>> fetchSubscriptionCredits() async {
    final orgId = await getOrgId();
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http
            .get(Uri.parse('$host/credits/$orgId'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          return jsonDecode(response.body);
        }
      } catch (_) {}
    }

    // Demo / Offline fallback data
    final prefs = await SharedPreferences.getInstance();
    final planName = prefs.getString('renttrack_active_plan_name') ?? '2 Days Free Trial';
    final credits = prefs.getInt('renttrack_demo_credits') ?? 50;

    return {
      'subscription': {
        'planType': 'CREDIT',
        'subscriptionName': planName,
        'expiresAt': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'isExpired': false,
        'daysRemaining': 2,
      },
      'credits': {
        'purchasedCredits': credits,
        'usedCredits': 0,
        'availableCredits': credits,
        'creditRule': 'Unused credits roll over and accumulate when new subscription packages are added.',
      },
    };
  }

  static Future<Map<String, dynamic>?> purchaseCredits(int creditsCount) async {
    final orgId = await getOrgId();
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.post(
          Uri.parse('$host/credits/purchase'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'organizationId': orgId,
            'creditsCount': creditsCount,
          }),
        ).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          return jsonDecode(response.body);
        }
      } catch (_) {}
    }

    // Demo fallback: update local credits
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('renttrack_demo_credits') ?? 50;
    final updated = current + creditsCount;
    await prefs.setInt('renttrack_demo_credits', updated);
    return {
      'message': '$creditsCount credits purchased successfully! Unused credits roll over.',
      'purchasedCredits': updated,
      'availableCredits': updated,
    };
  }

  static Future<Map<String, dynamic>?> subscribeAppPlan(String appPlanId, {String? planName, int? whatsappCredits}) async {
    final orgId = await getOrgId();
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.post(
          Uri.parse('$host/auth/organization/$orgId/subscribe-app-plan'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'appPlanId': appPlanId}),
        ).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          final data = jsonDecode(response.body);
          return data;
        }
      } catch (_) {}
    }

    // Demo fallback: store chosen plan locally
    final prefs = await SharedPreferences.getInstance();
    final resolvedPlanName = planName ?? (appPlanId.contains('2') ? '2 Days Free Trial' : 'Plus (1 Month)');
    final addedCredits = whatsappCredits ?? (appPlanId.contains('2') ? 50 : 250);
    final currentCredits = prefs.getInt('renttrack_demo_credits') ?? 0;
    final totalCredits = currentCredits + addedCredits; // Rollover

    await prefs.setString('renttrack_active_plan_name', resolvedPlanName);
    await prefs.setString('renttrack_chosen_plan_id', appPlanId);
    await prefs.setBool('renttrack_plan_chosen', true);
    await prefs.setInt('renttrack_demo_credits', totalCredits);

    return {
      'success': true,
      'message': 'Subscribed to $resolvedPlanName! $addedCredits WhatsApp credits added (total: $totalCredits).',
      'organization': {'selectedAppPlanId': appPlanId},
      'credits': {'available': totalCredits, 'total': totalCredits},
    };
  }

  static Future<Map<String, dynamic>?> sendPaymentReminder(String scheduleId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/send-reminder'),
        headers: await _authHeaders(),
        body: jsonEncode({'scheduleId': scheduleId}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error sending payment reminder: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> sendPaymentReceipt({
    String? scheduleId,
    String? transactionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/send-receipt'),
        headers: await _authHeaders(),
        body: jsonEncode({
          if (scheduleId != null) 'scheduleId': scheduleId,
          if (transactionId != null) 'transactionId': transactionId,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error sending payment receipt: $e');
    }
    return null;
  }

  // ─── Razorpay Payment Integration ──────────────────────────────────────────

  static Future<Map<String, dynamic>?> createSubscriptionRazorpayOrder({
    required String planId,
    required String planName,
    required double amount,
    required int credits,
  }) async {
    final orgId = await getOrgId();
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('renttrack_phone') ?? '9876543210';
    final name = prefs.getString('renttrack_user_name') ?? 'Property Owner';

    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.post(
          Uri.parse('$host/payments/razorpay/subscription-order'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'organizationId': orgId,
            'planId': planId,
            'planName': planName,
            'amount': amount,
            'credits': credits,
            'phone': phone,
            'name': name,
          }),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          return jsonDecode(response.body);
        } else {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) return decoded;
          } catch (_) {}
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<Map<String, dynamic>?> createCreditPackageRazorpayOrder({
    required String packageId,
    required String packageName,
    required double amount,
    required int credits,
  }) async {
    final orgId = await getOrgId();
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('renttrack_phone') ?? '9876543210';
    final name = prefs.getString('renttrack_user_name') ?? 'Property Owner';

    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.post(
          Uri.parse('$host/payments/razorpay/credit-order'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'organizationId': orgId,
            'packageId': packageId,
            'packageName': packageName,
            'amount': amount,
            'credits': credits,
            'phone': phone,
            'name': name,
          }),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          return jsonDecode(response.body);
        } else {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) return decoded;
          } catch (_) {}
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<Map<String, dynamic>> verifySubscriptionOrCreditPayment({
    required String type,
    String? planName,
    required int credits,
    String? paymentId,
    String? paymentLinkId,
  }) async {
    final orgId = await getOrgId();
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.post(
          Uri.parse('$host/payments/razorpay/verify-subscription'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'organizationId': orgId,
            'type': type,
            'planName': planName,
            'credits': credits,
            'paymentId': paymentId,
            'paymentLinkId': paymentLinkId,
          }),
        ).timeout(const Duration(seconds: 8));

        _activeBaseUrl = host;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return {
              ...decoded,
              'statusCode': response.statusCode,
              'success': response.statusCode == 200,
            };
          }
        } catch (_) {}

        return {
          'success': response.statusCode == 200,
          'statusCode': response.statusCode,
        };
      } catch (_) {}
    }
    return {'success': false, 'statusCode': 0, 'error': 'Network timeout or server unreachable'};
  }

  static Future<Map<String, dynamic>?> getPaymentLinkStatus(String linkId) async {
    for (final host in [_activeBaseUrl, ..._candidateHosts]) {
      try {
        final response = await http.get(
          Uri.parse('$host/payments/link-status/$linkId'),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _activeBaseUrl = host;
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return null;
  }
}
