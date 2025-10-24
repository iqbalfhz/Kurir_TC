class User {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: (json['id'] is int) ? json['id'] as int : 0,
    name: (json['name'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    avatarUrl: json['avatar_url'] as String?,
  );
}
