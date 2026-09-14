import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:5001/api';
  static const String demoOrgId = 'f1aac5fa-5087-41fd-9c13-e9f4b20eae81';

  static Future<Map<String, dynamic>> customerLogin(String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/customer-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> fetchFinancialSummary() async {
    final response = await http.get(Uri.parse('$baseUrl/reports/summary?organizationId=$demoOrgId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load financial summary');
  }

  static Future<List<dynamic>> fetchMembers({String? status, String? month, String? year}) async {
    String url = '$baseUrl/members?organizationId=$demoOrgId';
    if (status != null) {
      url += '&status=$status';
    }
    if (month != null) {
      url += '&month=$month';
    }
    if (year != null) {
      url += '&year=$year';
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['members'] ?? [];
    }
    throw Exception('Failed to load members');
  }

  static Future<Map<String, dynamic>> fetchMemberDetails(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/members/$id'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load member details');
  }

  static Future<Map<String, dynamic>> fetchMemberSchedules(String memberId) async {
    final response = await http.get(Uri.parse('$baseUrl/payments/schedules/$memberId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  static Future<bool> markAsPaid(String scheduleId, double amountPaid, {String paymentMethod = 'CASH', String? notes}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/mark-paid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'scheduleId': scheduleId,
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'notes': notes,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> markAsUnpaid(String scheduleId, {bool confirmed = false}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/mark-unpaid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'scheduleId': scheduleId,
        'confirmed': confirmed,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<bool> freezeMonth(String scheduleId, {String? notes}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/freeze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'scheduleId': scheduleId,
        'notes': notes ?? 'Month frozen by admin',
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> unfreezeMonth(String scheduleId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/unfreeze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'scheduleId': scheduleId,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> createRazorpayOrder(String scheduleId, String memberId, double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/razorpay/create-order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'scheduleId': scheduleId,
        'memberId': memberId,
        'amount': amount,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> fetchPlans() async {
    final response = await http.get(Uri.parse('$baseUrl/plans?organizationId=$demoOrgId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['plans'] ?? [];
    }
    return [];
  }

  static Future<bool> createMember(Map<String, dynamic> memberData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/members'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'organizationId': demoOrgId,
        ...memberData,
      }),
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

  static Future<bool> createPlan(Map<String, dynamic> planData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/plans'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'organizationId': demoOrgId,
        ...planData,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<List<dynamic>> fetchExpenses() async {
    final response = await http.get(Uri.parse('$baseUrl/expenses?organizationId=$demoOrgId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['expenses'] ?? [];
    }
    return [];
  }

  static Future<bool> createExpense(Map<String, dynamic> expenseData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'organizationId': demoOrgId,
        ...expenseData,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<List<dynamic>> fetchExpenseCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/expenses/categories?organizationId=$demoOrgId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['categories'] ?? [];
    }
    return [];
  }

  static Future<bool> createExpenseCategory(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses/categories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'organizationId': demoOrgId,
        'name': name,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> deleteExpenseCategory(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/expenses/categories/$id'));
    return response.statusCode == 200;
  }

  static Future<List<dynamic>> fetchWhatsAppTemplates() async {
    final response = await http.get(Uri.parse('$baseUrl/settings/whatsapp-templates?organizationId=$demoOrgId'));
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
}
