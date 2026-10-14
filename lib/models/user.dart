class AppUser {
  AppUser({
    this.userId,
    this.fullName = '',
    required this.username,
    required this.email,
    this.passwordHash = '',
    this.bio = '',
    this.avatarPath,
    this.bannerPath,
    this.gender,
    this.genderCustom,
    this.birthdate,
    this.role = 'user',
    this.createdAt,
  });

  int? userId;
  String fullName;
  String username;
  String email;
  String passwordHash;
  String bio;
  String? avatarPath;
  String? bannerPath;
  String? gender;
  String? genderCustom;
  String? birthdate;
  String role;
  String? createdAt;

  bool get isAdmin => role == 'admin';

  String get displayName =>
      fullName.trim().isNotEmpty ? fullName.trim() : username;

  String get initials {
    final parts =
        displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        if (userId != null) 'user_id': userId,
        'full_name': fullName,
        'username': username,
        'email': email,
        'password': passwordHash,
        'bio': bio,
        'avatar_path': avatarPath,
        'banner_path': bannerPath,
        'gender': gender,
        'gender_custom': genderCustom,
        'birthdate': birthdate,
        'role': role,
        if (createdAt != null) 'created_at': createdAt,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        userId: m['user_id'] as int?,
        fullName: (m['full_name'] as String?) ?? '',
        username: (m['username'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        passwordHash: (m['password'] as String?) ?? '',
        bio: (m['bio'] as String?) ?? '',
        avatarPath: m['avatar_path'] as String?,
        bannerPath: m['banner_path'] as String?,
        gender: m['gender'] as String?,
        genderCustom: m['gender_custom'] as String?,
        birthdate: m['birthdate'] as String?,
        role: (m['role'] as String?) ?? 'user',
        createdAt: m['created_at'] as String?,
      );
}