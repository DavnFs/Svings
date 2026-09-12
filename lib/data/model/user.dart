/// Authenticated user profile (mirrors `public.profiles` in Supabase).
class User {
  final String? idUser;       // = auth.users.id (uuid)
  final String? name;         // full_name
  final String? email;
  final String? avatarUrl;
  final String? phone;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    this.idUser,
    this.name,
    this.email,
    this.avatarUrl,
    this.phone,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromProfileJson(Map<String, dynamic> json) => User(
        idUser: json['id'] as String?,
        name: json['full_name'] as String?,
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String?,
        isActive: json['is_active'] as bool?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': idUser,
        'full_name': name,
        'email': email,
        'avatar_url': avatarUrl,
        'phone': phone,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Returns an empty profile (used by `Session.getUser` when not signed in).
  factory User.empty() => const User();
}
