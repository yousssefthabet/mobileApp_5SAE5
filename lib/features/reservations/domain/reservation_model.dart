/// A reservation as returned by the booking Cloud Functions.
class ReservationModel {
  const ReservationModel({
    required this.id,
    required this.chargerId,
    required this.connectorId,
    required this.stationName,
    required this.connectorName,
    required this.start,
    required this.end,
    required this.durationMinutes,
    required this.amount,
    required this.currency,
    required this.status,
  });

  final String id;
  final String chargerId;
  final int connectorId;
  final String stationName;
  final String connectorName;
  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final double amount;
  final String currency;
  final String status;

  bool get isConfirmed => status == 'confirmed';

  factory ReservationModel.fromMap(Map<dynamic, dynamic> map) {
    return ReservationModel(
      id: map['id'] as String,
      chargerId: map['chargerId'] as String,
      connectorId: (map['connectorId'] as num).toInt(),
      stationName: (map['stationName'] as String?) ?? '',
      connectorName: (map['connectorName'] as String?) ?? '',
      start: DateTime.parse(map['start'] as String).toLocal(),
      end: DateTime.parse(map['end'] as String).toLocal(),
      durationMinutes: (map['durationMinutes'] as num).toInt(),
      amount: (map['amount'] as num).toDouble(),
      currency: (map['currency'] as String?) ?? 'TND',
      status: map['status'] as String,
    );
  }
}
