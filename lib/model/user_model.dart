class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phoneNum;
  final DateTime createdAt;

  UserModel ({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNum,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        phoneNum: json['phone_num'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_num': phoneNum,
      'created_at': createdAt.toIso8601String(),
    };
  }
}