// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'payment_page.dart';

const Color _primaryGreen = Color(0xFF086B5B);
const Color _textDark = Color(0xFF1E2926);
const Color _textMuted = Color(0xFF7A8B86);
const Color _cardBorder = Color(0xFFE8ECEB);
const Color _chipBorder = Color(0xFFDEE5E2);
const Color _backgroundColor = Color(0xFFF7F9F8);

class ReserveSpotPage extends StatefulWidget {
  final String stationName;

  const ReserveSpotPage({
    super.key,
    this.stationName = 'Central Square Hub',
  });

  @override
  State<ReserveSpotPage> createState() => _ReserveSpotPageState();
}

class _ReserveSpotPageState extends State<ReserveSpotPage> {
  int _selectedConnector = 0; // 0: 1 · CCS, 1: 2 · CCS
  int _selectedDate = 0; // 0: Today, 1: Mon 12, 2: Tue 13
  int _selectedStartTime = 2; // 2: 10:30
  int _selectedDuration = 1; // 1: 1 hour

  final List<String> _connectors = ['1 · CCS', '2 · CCS'];
  final List<String> _dates = ['Today', 'Mon 12', 'Tue 13'];
  final List<String> _startTimes = [
    '09:30',
    '10:00', // disabled in design
    '10:30',
    '11:00',
    '11:30',
    '12:00',
  ];
  final List<String> _durations = ['30 min', '1 hour', '2 hours'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reserve a spot',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Station subtitle (Figure 9)
                  Text(
                    widget.stationName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 1. CONNECTOR SECTION
                  _buildSectionHeader('CONNECTOR'),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(_connectors.length, (index) {
                      final isSelected = _selectedConnector == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildSelectableChip(
                          label: _connectors[index],
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedConnector = index),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // 2. DATE SECTION
                  _buildSectionHeader('DATE'),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(_dates.length, (index) {
                      final isSelected = _selectedDate == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildSelectableChip(
                          label: _dates[index],
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedDate = index),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // 3. START TIME SECTION
                  _buildSectionHeader('START TIME'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(_startTimes.length, (index) {
                      final time = _startTimes[index];
                      final isUnavailable = index == 1; // 10:00 is disabled
                      final isSelected = _selectedStartTime == index;

                      return GestureDetector(
                        onTap: isUnavailable
                            ? null
                            : () => setState(() => _selectedStartTime = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _primaryGreen
                                : isUnavailable
                                    ? const Color(0xFFF2F4F3)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? _primaryGreen
                                  : isUnavailable
                                      ? const Color(0xFFE2E7E5)
                                      : _chipBorder,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : isUnavailable
                                      ? const Color(0xFFA8B5B1)
                                      : _textDark,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // 4. DURATION SECTION
                  _buildSectionHeader('DURATION'),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(_durations.length, (index) {
                      final isSelected = _selectedDuration == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildSelectableChip(
                          label: _durations[index],
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedDuration = index),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 28),

                  // 5. PRICING SUMMARY (Figure 9)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _cardBorder, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryPriceRow('Reservation fee', '[PRICE]'),
                        const SizedBox(height: 12),
                        _buildSummaryPriceRow('Estimated charging', '[PRICE]'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 6. Bottom Sticky Button: Continue to payment (Figure 9)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentPage(
                          stationName: widget.stationName,
                          connectorName: 'Connector ${_selectedConnector + 1}',
                          timeSlot: '${_dates[_selectedDate]} ${_startTimes[_selectedStartTime]} · ${_durations[_selectedDuration]}',
                          subtotal: '[PRICE]',
                          fees: '[PRICE]',
                          total: '[PRICE]',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Continue to payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: _textMuted,
      ),
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? _primaryGreen : _chipBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : _textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: _textMuted,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
      ],
    );
  }
}
