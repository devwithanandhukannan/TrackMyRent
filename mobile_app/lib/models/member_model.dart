class Member {
  final String id;
  final String fullName;
  final String phone;
  final String? planName;
  final String? groupName;
  final String duration;
  final DateTime joiningDate;
  final String status; // PAID, UNPAID, FROZEN
  final double amount;
  final Map<String, dynamic>? customFields;

  Member({
    required this.id,
    required this.fullName,
    required this.phone,
    this.planName,
    this.groupName,
    required this.duration,
    required this.joiningDate,
    required this.status,
    required this.amount,
    this.customFields,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      planName: json['plan']?['name'],
      groupName: json['group']?['name'],
      duration: json['duration'] ?? '30 Days',
      joiningDate: DateTime.parse(json['joiningDate'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'UNPAID',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      customFields: json['customFieldsData'],
    );
  }
}
