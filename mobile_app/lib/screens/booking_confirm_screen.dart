import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';

class BookingConfirmScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  const BookingConfirmScreen({super.key, this.bookingData});

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final booking       = widget.bookingData ?? {};
    final bookingRef    = booking['booking_reference']?.toString() ?? booking['id']?.toString() ?? booking['booking_id']?.toString() ?? '\u2014';
    final amount        = booking['total_amount']?.toString() ?? booking['amount']?.toString() ?? '0';
    final date          = booking['date']?.toString() ?? '\u2014';
    final sport         = booking['sport']?.toString() ?? booking['sport_name']?.toString() ?? '\u2014';
    final ground        = booking['ground']?.toString() ?? booking['ground_name']?.toString() ?? '\u2014';
    final paymentMethod = booking['payment_method']?.toString() ?? 'Pay at Ground';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),

              // Animated check icon
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.black,
                      size: 44,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      paymentMethod == 'Online'
                          ? 'Payment Successful!'
                          : 'Booking Confirmed!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      paymentMethod == 'Online'
                          ? 'Your payment is confirmed.\nSlot reserved — get ready to play!'
                          : 'Your slot has been reserved.\nGet ready to play!',
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Detail card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.elevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          _ConfirmRow(label: 'Booking Ref', value: bookingRef),
                          const SizedBox(height: 12),
                          Container(height: 1, color: colors.border),
                          const SizedBox(height: 12),
                          _ConfirmRow(label: 'Ground', value: ground),
                          const SizedBox(height: 10),
                          _ConfirmRow(label: 'Sport', value: sport),
                          const SizedBox(height: 10),
                          _ConfirmRow(label: 'Date', value: date),
                          const SizedBox(height: 10),
                          _ConfirmRow(
                            label: 'Amount',
                            value: '\u20b9$amount',
                            valueStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ConfirmRow(label: 'Payment', value: paymentMethod),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Actions
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.go('/my-bookings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'View My Bookings',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => context.go('/home'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Back to Home'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _ConfirmRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
        Text(
          value,
          style: valueStyle ??
              TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
        ),
      ],
    );
  }
}
