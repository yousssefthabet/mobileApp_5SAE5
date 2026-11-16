import 'package:flutter/material.dart';

import 'package:chargi/features/chatbot/domain/chat_models.dart';
import 'package:chargi/features/chatbot/presentation/widgets/chat_bubble.dart';

/// A station with its free connectors. When [onSelect] is set, tapping a free
/// connector picks it for the reservation being prepared.
class ChargerCard extends StatelessWidget {
  const ChargerCard({super.key, required this.charger, this.onSelect});

  final ChatCharger charger;
  final void Function(int connectorId)? onSelect;

  @override
  Widget build(BuildContext context) {
    final distance = charger.distanceKm;
    return Container(
      margin: const EdgeInsets.only(left: 40, top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E9E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.ev_station, size: 18, color: kChatGreen),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  charger.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (distance != null)
                Text(
                  '${distance.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kChatGreen,
                  ),
                ),
            ],
          ),
          if (charger.address != null && charger.address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                charger.address!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF5F6D69)),
              ),
            ),
          if (charger.pricePerKwh > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${charger.pricePerKwh.toStringAsFixed(2)} TND/kWh',
                style: const TextStyle(fontSize: 12, color: Color(0xFF5F6D69)),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in charger.connectors)
                _ConnectorChip(
                  connector: c,
                  onTap: (onSelect != null && c.available)
                      ? () => onSelect!(c.connectorId)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectorChip extends StatelessWidget {
  const _ConnectorChip({required this.connector, this.onTap});

  final ChatConnector connector;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        '${connector.type ?? 'Connector ${connector.connectorId}'} - '
        '${connector.powerKw.toStringAsFixed(connector.powerKw % 1 == 0 ? 0 : 1)} kW';
    final available = connector.available;
    final selectable = onTap != null;

    return Semantics(
      button: selectable,
      enabled: selectable || !available ? selectable : true,
      label: '$label, ${available ? 'available' : 'not available'}',
      child: Material(
        color: available
            ? (selectable ? kChatGreen : const Color(0xFFDDF1EB))
            : const Color(0xFFEDEFEE),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    available ? Icons.check_circle : Icons.block,
                    size: 14,
                    color: available
                        ? (selectable ? Colors.white : kChatGreen)
                        : const Color(0xFF8A9692),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: available
                          ? (selectable ? Colors.white : kChatGreen)
                          : const Color(0xFF8A9692),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
