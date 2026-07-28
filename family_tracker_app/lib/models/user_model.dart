class UserModel {
  final int id;
  final String username;
  final String? nickname;
  final String? role;

  UserModel({required this.id, required this.username, this.nickname, this.role});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'],
      role: json['role'],
    );
  }
}