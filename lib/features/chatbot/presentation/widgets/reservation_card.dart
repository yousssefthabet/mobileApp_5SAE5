import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:chargi/features/chatbot/presentation/widgets/chat_bubble.dart';
import 'package:chargi/features/reservations/domain/reservation_model.dart';
import 'package:chargi/screens/pages/reservation_confirmed_page.dart';

String reservationReference(String id) =>
    '#${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';

/// One reservation (reference, station, connector, date, time, duration,
/// price and status). Tappable when the user has to pick one.
class ReservationCard extends StatelessWidget {
  const ReservationCard({super.key, required this.reservation, this.onTap});

  final ReservationModel reservation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final d = '${r.start.day.toString().padLeft(2, '0')}/'
        '${r.start.month.toString().padLeft(2, '0')}/${r.start.year}';

    return Container(
      margin: const EdgeInsets.only(left: 40, top: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: onTap != null ? kChatGreen : const Color(0xFFE3E9E6),
                width: onTap != null ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reservationReference(r.id),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: kChatGreen,
                      ),
                    ),
                    const Spacer(),
                    _StatusChip(status: r.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r.stationName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  r.connectorName,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5F6D69)),
                ),
                const SizedBox(height: 6),
                Text(
                  '$d  ${chatTime(r.start)} - ${chatTime(r.end)}  '
                  '(${r.durationMinutes} min)',
                  style: const TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.amount.toStringAsFixed(2)} ${r.currency}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'confirmed' => (const Color(0xFFDDF1EB), kChatGreen),
      'cancelled' => (const Color(0xFFFDECEA), const Color(0xFF8A1C12)),
      _ => (const Color(0xFFEDEFEE), const Color(0xFF5F6D69)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Shown only AFTER the server confirmed the reservation: card + QR code.
class ConfirmedReservationCard extends StatelessWidget {
  const ConfirmedReservationCard({super.key, required this.reservation});

  final ReservationModel reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReservationCard(reservation: r),
        Container(
          margin: const EdgeInsets.only(left: 40, top: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E9E6)),
          ),
          child: Row(
            children: [
              Semantics(
                label: 'QR code for reservation ${reservationReference(r.id)}',
                child: QrImageView(
                  data: r.id,
                  size: 96,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservationReference(r.id),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kChatGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ReservationConfirmedPage(
                            stationName: r.stationName,
                            connectorInfo: r.connectorName,
                            timeSlot:
                                '${chatTime(r.start)} - ${chatTime(r.end)}',
                            heldFor: 'Confirmed',
                            reservationId: r.id,
                            amount:
                                '${r.amount.toStringAsFixed(2)} ${r.currency}',
                          ),
                        ),
                      ),
                      child: const Text('View pass'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
