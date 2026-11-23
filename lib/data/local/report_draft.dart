import 'dart:typed_data';

/// A report the citizen started but has not sent yet.
/// Stored only on the device, in SQLite (see [ReportDraftDb]).
class ReportDraft {
  final int? id; // null until inserted
  final String userId;
  final String title;
  final String description;
  final String address;
  final String landmark;
  final double? latitude;
  final double? longitude;
  final double mapOffsetX;
  final double mapOffsetY;
  final bool locationChosen;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Photo bytes, in order. Empty in list queries (only [photoCount] is loaded).
  final List<Uint8List> photos;
  final int photoCount;

  const ReportDraft({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.address = '',
    this.landmark = '',
    this.latitude,
    this.longitude,
    this.mapOffsetX = 0.5,
    this.mapOffsetY = 0.5,
    this.locationChosen = false,
    required this.createdAt,
    required this.updatedAt,
    this.photos = const [],
    int? photoCount,
  }) : photoCount = photoCount ?? photos.length;

  /// Row for the `report_drafts` table (photos go to `draft_photos`).
  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'address': address,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
        'map_offset_x': mapOffsetX,
        'map_offset_y': mapOffsetY,
        'location_chosen': locationChosen ? 1 : 0, // SQLite has no boolean type
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory ReportDraft.fromRow(Map<String, Object?> row, {List<Uint8List> photos = const []}) {
    return ReportDraft(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      address: (row['address'] as String?) ?? '',
      landmark: (row['landmark'] as String?) ?? '',
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      mapOffsetX: (row['map_offset_x'] as num?)?.toDouble() ?? 0.5,
      mapOffsetY: (row['map_offset_y'] as num?)?.toDouble() ?? 0.5,
      locationChosen: row['location_chosen'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      photos: photos,
      photoCount: (row['photo_count'] as int?) ?? photos.length,
    );
  }

  bool get isEmpty =>
      title.trim().isEmpty && description.trim().isEmpty && photoCount == 0 && !locationChosen;

  /// Short label for lists.
  String get displayTitle => title.trim().isNotEmpty ? title.trim() : 'Untitled draft';
}
