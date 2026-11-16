import 'package:flutter/material.dart';

import 'package:chargi/features/chatbot/domain/chat_models.dart';
import 'package:chargi/features/chatbot/presentation/widgets/chat_bubble.dart';

/// "Please confirm" card. The assistant never acts before the user taps
/// Confirm here.
class ConfirmationCard extends StatelessWidget {
  const ConfirmationCard({
    super.key,
    required this.pending,
    required this.status,
    required this.onConfirm,
    required this.onCancel,
    this.french = false,
  });

  final PendingAction pending;
  final PendingStatus status;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool french;

  @override
  Widget build(BuildContext context) {
    final open = status == PendingStatus.open;
    final confirming = status == PendingStatus.confirming;

    final confirmLabel = switch (pending.kind) {
      PendingKind.create => french ? 'Confirmer la réservation' : 'Confirm booking',
      PendingKind.cancel => french ? "Confirmer l'annulation" : 'Confirm cancellation',
      PendingKind.reschedule => french ? 'Confirmer le changement' : 'Confirm change',
    };

    return Container(
      margin: const EdgeInsets.only(left: 40, top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kChatGreen, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in pending.summary)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 108,
                    child: Text(
                      row.key,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5F6D69),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          if (open || confirming)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: open ? onConfirm : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: kChatGreen,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: confirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(confirmLabel),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: open ? onCancel : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(french ? 'Annuler' : 'Cancel'),
                ),
              ],
            )
          else
            Text(
              switch (status) {
                PendingStatus.confirmed => french ? 'Confirmé' : 'Confirmed',
                PendingStatus.dismissed => french ? 'Annulé' : 'Dismissed',
                _ => french ? 'Échec' : 'Failed',
              },
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: status == PendingStatus.confirmed
                    ? kChatGreen
                    : const Color(0xFF8A9692),
              ),
            ),
        ],
      ),
    );
  }
}
