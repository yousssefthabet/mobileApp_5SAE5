import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'report_draft.dart';

/// Local SQLite database (SQFlite) for report drafts.
///
/// Schema (version 1):
///   report_drafts (1) ──< draft_photos (n)
///   Deleting a draft deletes its photos (FOREIGN KEY ... ON DELETE CASCADE).
class ReportDraftDb {
  ReportDraftDb._();
  static final ReportDraftDb instance = ReportDraftDb._();

  static const String _dbName = 'chargi_reports.db';
  static const int _dbVersion = 1;

  static const String tDrafts = 'report_drafts';
  static const String tPhotos = 'draft_photos';

  Database? _db;

  /// Opens the database once and reuses it (singleton).
  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, _dbName),
      version: _dbVersion,
      // Foreign keys are OFF by default in SQLite: turn them on for CASCADE.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tDrafts (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id         TEXT    NOT NULL,
        title           TEXT    NOT NULL DEFAULT '',
        description     TEXT    NOT NULL DEFAULT '',
        address         TEXT    NOT NULL DEFAULT '',
        landmark        TEXT    NOT NULL DEFAULT '',
        latitude        REAL,
        longitude       REAL,
        map_offset_x    REAL    NOT NULL DEFAULT 0.5,
        map_offset_y    REAL    NOT NULL DEFAULT 0.5,
        location_chosen INTEGER NOT NULL DEFAULT 0,
        created_at      INTEGER NOT NULL,
        updated_at      INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tPhotos (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        draft_id  INTEGER NOT NULL,
        position  INTEGER NOT NULL,
        data      BLOB    NOT NULL,
        FOREIGN KEY (draft_id) REFERENCES $tDrafts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_drafts_user_updated ON $tDrafts(user_id, updated_at DESC)');
    await db.execute('CREATE INDEX idx_photos_draft ON $tPhotos(draft_id, position)');
  }

  /// Future schema changes go here (e.g. `if (oldVersion < 2) ALTER TABLE ...`).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  /// Inserts a draft and its photos in one transaction. Returns the new id.
  Future<int> insertDraft(ReportDraft draft) async {
    final db = await database;
    return db.transaction((txn) async {
      final row = draft.toRow()..remove('id');
      final id = await txn.insert(tDrafts, row);
      await _insertPhotos(txn, id, draft.photos);
      return id;
    });
  }

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  /// Lists the user's drafts, newest first, without photo bytes.
  /// [search] filters on title, description and address (SQL LIKE).
  Future<List<ReportDraft>> getDrafts(String userId, {String search = ''}) async {
    final db = await database;
    final q = search.trim();
    final rows = await db.rawQuery('''
      SELECT d.*,
             (SELECT COUNT(*) FROM $tPhotos ph WHERE ph.draft_id = d.id) AS photo_count
      FROM $tDrafts d
      WHERE d.user_id = ?
        ${q.isEmpty ? '' : 'AND (d.title LIKE ? OR d.description LIKE ? OR d.address LIKE ?)'}
      ORDER BY d.updated_at DESC
    ''', [userId, if (q.isNotEmpty) ...['%$q%', '%$q%', '%$q%']]);
    return rows.map(ReportDraft.fromRow).toList();
  }

  /// Loads one draft with all its photos (in order).
  Future<ReportDraft?> getDraft(int id) async {
    final db = await database;
    final rows = await db.query(tDrafts, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final photoRows = await db.query(
      tPhotos,
      columns: ['data'],
      where: 'draft_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    final photos = photoRows.map((r) => r['data'] as Uint8List).toList();
    return ReportDraft.fromRow(rows.first, photos: photos);
  }

  Future<int> countDrafts(String userId) async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM $tDrafts WHERE user_id = ?', [userId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  /// Updates a draft and replaces its photos in one transaction.
  Future<void> updateDraft(ReportDraft draft) async {
    if (draft.id == null) throw ArgumentError('Draft has no id');
    final db = await database;
    await db.transaction((txn) async {
      final row = draft.toRow()
        ..remove('id')
        ..remove('created_at');
      await txn.update(tDrafts, row, where: 'id = ?', whereArgs: [draft.id]);
      await txn.delete(tPhotos, where: 'draft_id = ?', whereArgs: [draft.id]);
      await _insertPhotos(txn, draft.id!, draft.photos);
    });
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  /// Deletes a draft; its photos are deleted by ON DELETE CASCADE.
  Future<void> deleteDraft(int id) async {
    final db = await database;
    await db.delete(tDrafts, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllDrafts(String userId) async {
    final db = await database;
    await db.delete(tDrafts, where: 'user_id = ?', whereArgs: [userId]);
  }

  // ---------------------------------------------------------------------------

  Future<void> _insertPhotos(Transaction txn, int draftId, List<Uint8List> photos) async {
    final batch = txn.batch();
    for (var i = 0; i < photos.length; i++) {
      batch.insert(tPhotos, {'draft_id': draftId, 'position': i, 'data': photos[i]});
    }
    await batch.commit(noResult: true);
  }
}
