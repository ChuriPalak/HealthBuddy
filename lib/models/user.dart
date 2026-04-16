import 'dart:convert';

enum UserType { patient, provider, admin }

class User {
  final String id;
  final String name;
  final UserType userType;
  final List<String> emergencyContactIds;

  User({
    required this.id,
    required this.name,
    required this.userType,
    List<String>? emergencyContactIds,
  }) : emergencyContactIds = emergencyContactIds ?? <String>[];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'userType': userType.name,
        'emergencyContactIds': emergencyContactIds,
      };

  factory User.fromJson(Map<String, dynamic> json) {
    final typeString = json['userType'] as String? ?? 'patient';
    return User(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      userType: UserType.values.firstWhere(
        (e) => e.name == typeString,
        orElse: () => UserType.patient,
      ),
      emergencyContactIds: List<String>.from(json['emergencyContactIds'] ?? []),
    );
  }

  static String encodeList(List<User> users) =>
      jsonEncode(users.map((u) => u.toJson()).toList());

  static List<User> decodeList(String data) {
    final list = jsonDecode(data) as List<dynamic>;
    return list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }
}
