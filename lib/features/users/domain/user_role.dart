/// Role of a signed-in user, stored in `users/{uid}.role`.
///
/// Users never choose their role: it is created as `user` at sign-up and can
/// only be changed by an admin (Firebase console / Admin SDK). Firestore
/// security rules reject any attempt to change it from the app.
enum UserRole {
  user,
  worker,
  admin;

  /// Parses the raw Firestore field. Anything missing, empty or unknown is
  /// treated as [UserRole.user] (fail closed: no extra privileges).
  static UserRole parse(Object? raw) {
    if (raw is! String) return UserRole.user;
    switch (raw.trim().toLowerCase()) {
      case 'worker':
        return UserRole.worker;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.user;
    }
  }

  /// Role from a `users/{uid}` document's data (null when the document does
  /// not exist yet).
  static UserRole fromData(Map<String, dynamic>? data) => parse(data?['role']);

  /// Workers and admins can open the technician portal.
  bool get canUseWorkerPortal =>
      this == UserRole.worker || this == UserRole.admin;
}
