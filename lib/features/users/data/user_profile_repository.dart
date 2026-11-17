import 'package:cloud_firestore/cloud_firestore.dart';

/// Storage behind [UserProfileRepository] (a fake in tests).
abstract class ProfileStore {
  /// Atomically creates `users/{uid}` ONLY if it does not exist yet.
  /// Returns true when it was created, false when it already existed.
  Future<bool> createIfAbsent(String uid, Map<String, Object?> data);
}

class FirestoreProfileStore implements ProfileStore {
  FirestoreProfileStore({this._firestore});

  final FirebaseFirestore? _firestore;

  @override
  Future<bool> createIfAbsent(String uid, Map<String, Object?> data) {
    final db = _firestore ?? FirebaseFirestore.instance;
    final ref = db.collection('users').doc(uid);
    return db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return false;
      tx.set(ref, data);
      return true;
    });
  }
}

/// Makes sure a signed-in user has a profile document.
class UserProfileRepository {
  UserProfileRepository({ProfileStore? store})
      : _store = store ?? FirestoreProfileStore();

  final ProfileStore _store;

  /// Creates the profile on first sign-in (for example with Google) and does
  /// nothing if it already exists, so an existing profile, and above all an
  /// existing role (worker/admin), is never overwritten.
  ///
  /// Returns true when a new profile was created.
  Future<bool> ensureProfile({
    required String uid,
    String? email,
    String? displayName,
  }) {
    return _store.createIfAbsent(
      uid,
      newProfileData(email: email, displayName: displayName),
    );
  }

  /// The data of a brand-new profile. The role is always "user": the
  /// Firestore rules refuse anything else at creation.
  static Map<String, Object?> newProfileData({
    String? email,
    String? displayName,
  }) {
    return {
      'name': _nameFor(displayName, email),
      'email': email,
      'role': 'user',
      'rewardPoints': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String _nameFor(String? displayName, String? email) {
    final name = displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final local = email?.split('@').first.trim() ?? '';
    return local.isNotEmpty ? local : 'Chargi user';
  }
}
