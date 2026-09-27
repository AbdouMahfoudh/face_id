/// Logged-in account, as returned by the server (cached for offline use).
class UserSession {
  final String token;
  final int userId;
  final String username;
  final String fullName;
  final String role;
  final int schoolId;
  final String schoolName;
  final bool canScan;
  final bool canEdit;
  final bool canDelete;
  final bool canSeeSensitive;

  const UserSession({
    required this.token,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.schoolId,
    required this.schoolName,
    required this.canScan,
    required this.canEdit,
    required this.canDelete,
    required this.canSeeSensitive,
  });

  bool get isAdmin => role == 'admin';

  /// Builds a session from the server's "user" object.
  factory UserSession.fromUser(String token, Map<String, dynamic> u) {
    final school = u['school'] as Map<String, dynamic>;
    final perms = u['permissions'] as Map<String, dynamic>;
    final admin = u['role'] == 'admin';
    bool perm(String k) => admin || perms[k] == true;
    return UserSession(
      token: token,
      userId: (u['id'] as num).toInt(),
      username: u['username'] as String,
      fullName: u['full_name'] as String,
      role: u['role'] as String,
      schoolId: (school['id'] as num).toInt(),
      schoolName: school['name'] as String,
      canScan: perm('scan'),
      canEdit: perm('edit'),
      canDelete: perm('delete'),
      canSeeSensitive: perm('sensitive'),
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'user': {
      'id': userId,
      'username': username,
      'full_name': fullName,
      'role': role,
      'school': {'id': schoolId, 'name': schoolName},
      'permissions': {
        'scan': canScan,
        'edit': canEdit,
        'delete': canDelete,
        'sensitive': canSeeSensitive,
      },
    },
  };

  factory UserSession.fromJson(Map<String, dynamic> j) => UserSession.fromUser(
    j['token'] as String,
    j['user'] as Map<String, dynamic>,
  );
}
