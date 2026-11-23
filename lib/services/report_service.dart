import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:chargi/features/users/domain/user_role.dart';

/// The lifecycle of a report. The string keys are what is stored in Firestore.
class ReportStatus {
  ReportStatus._();

  static const String sent = 'sent';
  static const String assigned = 'assigned';
  static const String inProgress = 'in_progress';
  static const String resolved = 'resolved';

  static const List<String> all = [sent, assigned, inProgress, resolved];

  static String normalize(String? status) {
    final s = (status ?? sent).toLowerCase();
    return all.contains(s) ? s : sent;
  }

  static String label(String? status) {
    switch (normalize(status)) {
      case assigned:
        return 'Assigned';
      case inProgress:
        return 'Work in progress';
      case resolved:
        return 'Resolved';
      case sent:
      default:
        return 'Sent';
    }
  }

  static IconData icon(String? status) {
    switch (normalize(status)) {
      case assigned:
        return Icons.person_pin_circle_outlined;
      case inProgress:
        return Icons.construction;
      case resolved:
        return Icons.check_circle_outline;
      case sent:
      default:
        return Icons.mark_email_read_outlined;
    }
  }

  static Color background(String? status) {
    switch (normalize(status)) {
      case assigned:
        return const Color(0xFFE8F1FC);
      case inProgress:
        return const Color(0xFFFDEEE5);
      case resolved:
        return const Color(0xFFE4F3EE);
      case sent:
      default:
        return const Color(0xFFE2EFEA);
    }
  }

  static Color foreground(String? status) {
    switch (normalize(status)) {
      case assigned:
        return const Color(0xFF1E63B8);
      case inProgress:
        return const Color(0xFFC05218);
      case resolved:
        return const Color(0xFF0D6855);
      case sent:
      default:
        return const Color(0xFF086B5B);
    }
  }
}

/// All reads and writes for incident reports and the notifications sent to
/// their authors.
///
/// Reports live in `users/{ownerUid}/reports/{reportId}`; notifications in
/// `users/{ownerUid}/notifications/{notificationId}`.
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reportsOf(String uid) =>
      _db.collection('users').doc(uid).collection('reports');

  CollectionReference<Map<String, dynamic>> _notificationsOf(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  DocumentReference<Map<String, dynamic>> reportRef(String ownerUid, String reportId) =>
      _reportsOf(ownerUid).doc(reportId);

  /// The owner of a report is the user document two levels above it.
  String ownerOf(DocumentReference<Map<String, dynamic>> ref) => ref.parent.parent!.id;

  // ---------------------------------------------------------------------------
  // Roles
  // ---------------------------------------------------------------------------

  /// True while the signed-in user's document has `role: 'worker'`.
  /// The role can only be set from the Firebase console (see firestore.rules).
  Stream<bool> watchIsWorker() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);
    return _db
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => UserRole.fromData(doc.data()).canUseWorkerPortal)
        .handleError((Object e) => debugPrint('Role check failed: $e'));
  }

  Future<String> currentWorkerName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Worker';
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final name = (doc.data()?['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? 'Worker');
  }

  // ---------------------------------------------------------------------------
  // Author (citizen) side
  // ---------------------------------------------------------------------------

  /// Updates the editable fields of the signed-in user's own report.
  Future<void> updateOwnReport({
    required String reportId,
    required Map<String, dynamic> fields,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    await _reportsOf(user.uid).doc(reportId).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
      'editedByOwnerAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes the signed-in user's own report.
  Future<void> deleteOwnReport(String reportId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    await _reportsOf(user.uid).doc(reportId).delete();
  }

  // ---------------------------------------------------------------------------
  // Worker side
  // ---------------------------------------------------------------------------

  /// Every user's reports, newest first. Sorted on the device so no extra
  /// collection-group index has to be created in Firebase.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAllReports() {
    return _db.collectionGroup('reports').snapshots().map((snap) {
      final docs = snap.docs
          // Skip the unused top-level /reports collection.
          .where((d) => d.reference.parent.parent != null)
          .toList();
      docs.sort((a, b) {
        final ta = a.data()['createdAt'];
        final tb = b.data()['createdAt'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        if (ta is Timestamp) return -1;
        if (tb is Timestamp) return 1;
        return 0;
      });
      return docs;
    });
  }

  /// Changes the status of a report and notifies its author in the same write.
  Future<void> setStatus({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> currentData,
    required String newStatus,
    String? workerName,
    String? estimatedArrival,
  }) async {
    final status = ReportStatus.normalize(newStatus);
    final worker = (workerName?.trim().isNotEmpty ?? false)
        ? workerName!.trim()
        : await currentWorkerName();
    final eta = estimatedArrival?.trim() ?? '';

    final update = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      '${status}At': FieldValue.serverTimestamp(),
    };
    switch (status) {
      case ReportStatus.sent:
        update['workerName'] = 'Unassigned';
        update['estimatedArrival'] = 'Reviewing report';
        break;
      case ReportStatus.assigned:
        update['workerName'] = worker;
        update['estimatedArrival'] = eta.isNotEmpty ? eta : 'Scheduled soon';
        break;
      case ReportStatus.inProgress:
        update['workerName'] = worker;
        update['estimatedArrival'] = eta.isNotEmpty ? eta : 'Work has started';
        break;
      case ReportStatus.resolved:
        update['workerName'] = worker;
        update['estimatedArrival'] = 'Completed';
        break;
    }

    final title = _titleOf(currentData);
    final reference = _referenceOf(ref, currentData);
    final String notifTitle;
    final String notifBody;
    switch (status) {
      case ReportStatus.assigned:
        notifTitle = 'Your report was assigned';
        notifBody = '$reference "$title" was assigned to $worker.';
        break;
      case ReportStatus.inProgress:
        notifTitle = 'Work has started';
        notifBody = '$worker started working on $reference "$title".';
        break;
      case ReportStatus.resolved:
        notifTitle = 'Report resolved';
        notifBody = '$reference "$title" has been fixed. Thank you for reporting!';
        break;
      case ReportStatus.sent:
      default:
        notifTitle = 'Report status updated';
        notifBody = '$reference "$title" is back under review.';
        break;
    }

    final batch = _db.batch();
    batch.update(ref, update);
    _addNotification(
      batch,
      ownerUid: ownerOf(ref),
      reportId: ref.id,
      type: 'status',
      status: status,
      title: notifTitle,
      body: notifBody,
    );
    await batch.commit();
  }

  /// Lets a worker correct the title / description / location of any report.
  Future<void> workerEditReport({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> currentData,
    required Map<String, dynamic> fields,
  }) async {
    final worker = await currentWorkerName();
    final newTitle = (fields['problemTitle'] as String?) ?? _titleOf(currentData);

    final batch = _db.batch();
    batch.update(ref, {
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
      'editedByWorker': worker,
    });
    _addNotification(
      batch,
      ownerUid: ownerOf(ref),
      reportId: ref.id,
      type: 'edited',
      status: ReportStatus.normalize(currentData['status'] as String?),
      title: 'Your report was updated',
      body: '$worker updated the details of ${_referenceOf(ref, currentData)} "$newTitle".',
    );
    await batch.commit();
  }

  /// Deletes any report and tells its author why it disappeared.
  Future<void> workerDeleteReport({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> currentData,
    String? reason,
  }) async {
    final worker = await currentWorkerName();
    final why = reason?.trim() ?? '';

    final batch = _db.batch();
    batch.delete(ref);
    _addNotification(
      batch,
      ownerUid: ownerOf(ref),
      reportId: null, // the report no longer exists
      type: 'deleted',
      status: null,
      title: 'Your report was removed',
      body: '${_referenceOf(ref, currentData)} "${_titleOf(currentData)}" was removed by $worker.'
          '${why.isNotEmpty ? ' Reason: $why' : ''}',
    );
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Notifications (read by the report author)
  // ---------------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return _notificationsOf(user.uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Stream<int> watchUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);
    return _notificationsOf(user.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length)
        .handleError((Object e) => debugPrint('Unread count failed: $e'));
  }

  Future<void> markRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _notificationsOf(user.uid).doc(notificationId).update({'read': true});
  }

  Future<void> markAllRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final unread = await _notificationsOf(user.uid).where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _notificationsOf(user.uid).doc(notificationId).delete();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _addNotification(
    WriteBatch batch, {
    required String ownerUid,
    required String? reportId,
    required String type,
    required String? status,
    required String title,
    required String body,
  }) {
    final ref = _notificationsOf(ownerUid).doc();
    batch.set(ref, {
      'id': ref.id,
      'type': type,
      'reportId': reportId,
      'status': status,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  String _titleOf(Map<String, dynamic> data) =>
      (data['problemTitle'] as String?)?.trim().isNotEmpty == true
          ? (data['problemTitle'] as String).trim()
          : 'Report';

  String _referenceOf(DocumentReference ref, Map<String, dynamic> data) =>
      (data['reference'] as String?) ?? '#${ref.id.substring(0, 6).toUpperCase()}';
}
