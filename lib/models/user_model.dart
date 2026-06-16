class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? 'Unknown',
      email: data['email'] ?? '',
      role: data['role'] ?? 'unassigned',
    );
  }

  bool get isManager => role == 'manager';
  bool get isViewOnly => role == 'view_only';
  bool get isStockRep => role == 'stock_rep';
  bool get isCashier => role == 'cashier';
  bool get isBackup => role == 'backup';
}