// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'reservation_confirmed_page.dart';

const Color _primaryGreen = Color(0xFF086B5B);
const Color _textDark = Color(0xFF1E2926);
const Color _textMuted = Color(0xFF7A8B86);
const Color _cardBorder = Color(0xFFE8ECEB);
const Color _backgroundColor = Color(0xFFF7F9F8);

class PaymentPage extends StatefulWidget {
  final String stationName;
  final String connectorName;
  final String timeSlot;
  final String subtotal;
  final String fees;
  final String total;

  const PaymentPage({
    super.key,
    this.stationName = 'Central Square Hub',
    this.connectorName = 'Connector 1',
    this.timeSlot = 'Today 10:30 · 1 hour',
    this.subtotal = '[PRICE]',
    this.fees = '[PRICE]',
    this.total = '[PRICE]',
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  int _selectedPaymentMethod = 0; // 0: Bank card, 1: Wallet, 2: Add card
  final TextEditingController _promoController = TextEditingController();
  bool _promoApplied = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

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
          'Payment',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Station Summary Card (Figure 5)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _cardBorder, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stationName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.connectorName} · ${widget.timeSlot}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section Title: PAY WITH
                  const Text(
                    'PAY WITH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: _textMuted,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Payment Options (Figure 5)
                  // Option 0: Bank card
                  _buildPaymentOption(
                    index: 0,
                    icon: Icons.credit_card_outlined,
                    title: 'Bank card',
                    subtitle: 'Visa ending in [XXXX]',
                  ),

                  const SizedBox(height: 12),

                  // Option 1: Wallet
                  _buildPaymentOption(
                    index: 1,
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet',
                    subtitle: 'Balance [PRICE]',
                  ),

                  const SizedBox(height: 12),

                  // Option 2: Add a new card
                  _buildPaymentOption(
                    index: 2,
                    icon: Icons.add_card_outlined,
                    title: 'Add a new card',
                    subtitle: 'Visa, Mastercard',
                  ),

                  const SizedBox(height: 20),

                  // 3. Promo code Container (Figure 5)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cardBorder, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoController,
                            decoration: const InputDecoration(
                              hintText: 'Promo code',
                              hintStyle: TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (_promoController.text.trim().isNotEmpty) {
                              setState(() {
                                _promoApplied = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Promo code applied successfully!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: Text(
                            _promoApplied ? 'Applied ✓' : 'Apply',
                            style: const TextStyle(
                              color: _primaryGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Breakdown Table (Figure 5)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _cardBorder, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow('Subtotal', widget.subtotal),
                        const SizedBox(height: 12),
                        _buildPriceRow('Fees', widget.fees),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Divider(color: Color(0xFFECEFEF), height: 1),
                        ),
                        _buildPriceRow('Total', widget.total, isTotal: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 5. Bottom Sticky Button: Pay [PRICE] (Figure 5)
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
                    // Navigate to Reservation Confirmed Page (Figure 8)
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReservationConfirmedPage(
                          stationName: widget.stationName,
                          connectorInfo: '${widget.connectorName} · CCS',
                          timeSlot: widget.timeSlot,
                          heldFor: '14:52',
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
                  child: Text(
                    'Pay ${widget.total}',
                    style: const TextStyle(
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

  Widget _buildPaymentOption({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedPaymentMethod == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryGreen : _cardBorder,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? _primaryGreen : _textDark,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _primaryGreen : const Color(0xFFCCD6D2),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: _primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: _textDark,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 17 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: _textDark,
          ),
        ),
      ],
    );
  }
}
