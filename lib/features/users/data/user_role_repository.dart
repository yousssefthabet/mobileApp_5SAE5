import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:chargi/features/users/domain/user_role.dart';

/// Emits the raw data of `users/{uid}` (null when the document is missing).
typedef UserDocumentSource = Stream<Map<String, dynamic>?> Function(String uid);

Stream<Map<String, dynamic>?> _firestoreUserDocument(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data());
}

/// Single place that reads a user's role.
class UserRoleRepository {
  UserRoleRepository({UserDocumentSource? documentSource})
      : _source = documentSource ?? _firestoreUserDocument;

  final UserDocumentSource _source;

  /// Live role of [uid]. A missing document, a missing `role` field, an
  /// unknown value or any read error all yield [UserRole.user]: if the role
  /// cannot be established, no privileges are granted.
  Stream<UserRole> watchRole(String uid) {
    return _source(uid).transform(
      StreamTransformer<Map<String, dynamic>?, UserRole>.fromHandlers(
        handleData: (data, sink) => sink.add(UserRole.fromData(data)),
        handleError: (error, stackTrace, sink) => sink.add(UserRole.user),
      ),
    );
  }
}
