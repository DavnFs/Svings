/// Authenticated user profile (mirrors `public.profiles` in Supabase).
class User {
  final String? idUser;       // = auth.users.id (uuid)
  final String? name;         // full_name
  final String? email;
  final String? phone;

  const User({
    this.idUser,
    this.name,
    this.email,
    this.phone,
  });

  factory User.fromProfileJson(Map<String, dynamic> json) => User(
        idUser: json['id'] as String?,
        name: json['full_name'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': idUser,
        'full_name': name,
        'email': email,
        'phone': phone,
      };

  /// Returns an empty profile (used by `Session.getUser` when not signed in).
  factory User.empty() => const User();
}
