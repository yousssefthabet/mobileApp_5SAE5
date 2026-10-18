
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'payment_page.dart';

class ReserveSpotPage extends StatefulWidget {
  final String chargerId;
  final String stationName;
  final int initialConnectorIndex;

  const ReserveSpotPage({
    super.key,
    required this.chargerId,
    this.stationName = 'Charging station',
    this.initialConnectorIndex = 0,
  });

  @override
  State<ReserveSpotPage> createState() => _ReserveSpotPageState();
}

class _ReserveSpotPageState extends State<ReserveSpotPage> {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(minutes: 5)),
  );
  int _selectedDurationMinutes = 60;
  int? _selectedConnectorId;
  bool _isOpeningPayment = false;

  double _number(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _connectorId(dynamic value, {int fallback = -1}) {
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  int _extractConnectorId(Map<String, dynamic> c, int fallbackIndex) {
    final raw = c['connectorId'] ?? c['id'] ?? c['connector_id'];
    return _connectorId(raw, fallback: fallbackIndex >= 0 ? fallbackIndex + 1 : 1);
  }

  DateTime get _startDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  String _money(double amount) => '${amount.toStringAsFixed(2)} TND';

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeSlot(DateTime start, int durationMinutes) {
    final end = start.add(Duration(minutes: durationMinutes));
    return '${_formatDate(start)} · ${_formatTime(start)}'
        ' – ${_formatTime(end)}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(
        DateTime(now.year, now.month, now.day),
      )
          ? now
          : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );

    if (result != null && mounted) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (result != null && mounted) {
      setState(() => _selectedTime = result);
    }
  }

  Future<void> _continueToPayment({
    required Map<String, dynamic> charger,
    required Map<String, dynamic> connector,
    required double pricePerKwh,
    required double reservationFee,
  }) async {
    if (_isOpeningPayment) return;

    final now = DateTime.now();
    final start = _startDateTime;

    // Allow reservations for now/today with a 15-minute tolerance
    if (start.isBefore(now.subtract(const Duration(minutes: 15)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future reservation time.'),
        ),
      );
      return;
    }

    final effectiveStart = start.isBefore(now) ? now : start;

    final connectorId = _extractConnectorId(connector, 0);

    if (connectorId < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid connector ID. Please select another.'),
        ),
      );
      return;
    }

    final powerKw = _number(
      connector['power'],
      fallback: _number(charger['maxPower']),
    );

    // Estimate assumes the connector operates at rated power
    // throughout the selected duration.
    final estimatedCharging =
        powerKw * (_selectedDurationMinutes / 60.0) * pricePerKwh;

    final total = estimatedCharging + reservationFee;

    setState(() => _isOpeningPayment = true);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            chargerId: widget.chargerId,
            connectorId: connectorId,
            startDateTime: effectiveStart,
            durationMinutes: _selectedDurationMinutes,
            amount: total,
            stationName: widget.stationName,
            connectorName:
                'Connector $connectorId · ${connector['type'] ?? 'Standard'}',
            timeSlot: _formatTimeSlot(
              effectiveStart,
              _selectedDurationMinutes,
            ),
            subtotal: _money(estimatedCharging),
            fees: _money(reservationFee),
            total: _money(total),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chargerRef = FirebaseFirestore.instance
        .collection('ev_chargers')
        .doc(widget.chargerId);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Reserve a spot',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: chargerRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load charging station details.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Charging station not found.'),
            );
          }

          final charger = snapshot.data!.data()!;

          if (charger['isActive'] == false) {
            return const Center(
              child: Text('This charging station is currently inactive.'),
            );
          }

          final rawConnectors = charger['connectors'];

          final allConnectors = rawConnectors is List
              ? rawConnectors
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : <Map<String, dynamic>>[];

          final availableConnectors = allConnectors.where((connector) {
            return connector['status']?.toString().toLowerCase() == 'free';
          }).toList();

          Map<String, dynamic>? selectedConnector;

          for (int i = 0; i < availableConnectors.length; i++) {
            final connector = availableConnectors[i];
            if (_extractConnectorId(connector, allConnectors.indexOf(connector)) ==
                _selectedConnectorId) {
              selectedConnector = connector;
              break;
            }
          }

          final effectiveConnector = selectedConnector ??
              (availableConnectors.isNotEmpty
                  ? (widget.initialConnectorIndex >= 0 &&
                          widget.initialConnectorIndex < allConnectors.length &&
                          availableConnectors.contains(allConnectors[widget.initialConnectorIndex])
                      ? allConnectors[widget.initialConnectorIndex]
                      : availableConnectors.first)
                  : null);

          final pricePerKwh = _number(
            charger['pricePerKwh'] ??
                charger['price_per_kwh'] ??
                charger['price'],
          );

          final reservationFee = _number(
            charger['reservationFee'] ?? charger['reservation_fee'],
          );

          final powerKw = effectiveConnector == null
              ? 0.0
              : _number(
                  effectiveConnector['power'],
                  fallback: _number(charger['maxPower']),
                );

          final estimatedCharging = powerKw *
              (_selectedDurationMinutes / 60.0) *
              pricePerKwh;

          final total = estimatedCharging + reservationFee;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2EFEA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.ev_station,
                        color: primaryGreen,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.stationName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${availableConnectors.length} connector(s) available',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Choose a connector',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              if (availableConnectors.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'No connectors are currently available. Please try again later.',
                  ),
                )
              else
                ...availableConnectors.map((connector) {
                  final id = _extractConnectorId(
                    connector,
                    allConnectors.indexOf(connector),
                  );
                  final isSelected = effectiveConnector != null &&
                      _extractConnectorId(
                            effectiveConnector,
                            allConnectors.indexOf(effectiveConnector),
                          ) ==
                          id;

                  final power = _number(
                    connector['power'],
                    fallback: _number(charger['maxPower']),
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() {
                        _selectedConnectorId = id;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? primaryGreen
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.electrical_services,
                              color: primaryGreen,
                              size: 27,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Connector $id · ${connector['type'] ?? 'Standard'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${power.toStringAsFixed(0)} kW · Available',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? primaryGreen
                                  : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 18),

              const Text(
                'Reservation date and time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _selectionButton(
                      icon: Icons.calendar_today_outlined,
                      label: _formatDate(_selectedDate),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _selectionButton(
                      icon: Icons.access_time,
                      label: _selectedTime.format(context),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Charging duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [30, 60, 120].map((minutes) {
                  final selected = _selectedDurationMinutes == minutes;

                  return ChoiceChip(
                    label: Text(
                      minutes < 60
                          ? '$minutes min'
                          : '${minutes ~/ 60} hour${minutes >= 120 ? 's' : ''}',
                    ),
                    selected: selected,
                    selectedColor: const Color(0xFFE2EFEA),
                    onSelected: (_) {
                      setState(() => _selectedDurationMinutes = minutes);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _priceRow(
                      'Charging estimate',
                      _money(estimatedCharging),
                    ),
                    const SizedBox(height: 12),
                    _priceRow(
                      'Reservation fee',
                      _money(reservationFee),
                    ),
                    const Divider(height: 28),
                    _priceRow('Total', _money(total), bold: true),
                    const SizedBox(height: 10),
                    Text(
                      'Estimated price only. Actual charging costs may vary.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: effectiveConnector == null ||
                          _isOpeningPayment
                      ? null
                      : () => _continueToPayment(
                            charger: charger,
                            connector: effectiveConnector,
                            pricePerKwh: pricePerKwh,
                            reservationFee: reservationFee,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isOpeningPayment
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Continue to payment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _selectionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: bold ? primaryGreen : Colors.black87,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 17 : 14,
          ),
        ),
      ],
    );
  }
}
