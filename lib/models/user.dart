// lib/models/user.dart

class User {
  final String userId;
  final String email;
  final String? phoneNumber;
  final String firstName;
  final String lastName;
  final String? organization;
  final bool isCorporate;
  final String role;
  final String? profileImageUrl;
  final bool emailVerified;
  final bool phoneVerified;

  User({
    required this.userId,
    required this.email,
    this.phoneNumber,
    required this.firstName,
    required this.lastName,
    this.organization,
    required this.isCorporate,
    required this.role,
    this.profileImageUrl,
    required this.emailVerified,
    required this.phoneVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      organization: json['organization'],
      isCorporate: json['is_corporate'] ?? false,
      role: json['role'],
      profileImageUrl: json['profile_image_url'],
      emailVerified: json['email_verified'] ?? false,
      phoneVerified: json['phone_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'phone_number': phoneNumber,
      'first_name': firstName,
      'last_name': lastName,
      'organization': organization,
      'is_corporate': isCorporate,
      'role': role,
      'profile_image_url': profileImageUrl,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
    };
  }

  String get fullName => '$firstName $lastName';
}