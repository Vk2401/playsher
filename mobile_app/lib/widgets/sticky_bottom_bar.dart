import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class StickyBottomBar extends StatelessWidget {
  final String? price;
  final String? priceLabel;

  /// A third line under [price] — "Total Amount" on the checkout bar, where
  /// the number above it is the payable-now figure and this says what it's
  /// a share of.
  final String? priceCaption;

  /// Trust copy shown once the price is committed to, not repeated per row —
  /// "Secure by Razorpay" beside the amount rather than on every payment
  /// option above it.
  final Widget? secureNote;

  final String buttonText;

  /// A line under the button — "Instant Confirmation" — for the moment the
  /// tap itself needs a reason beyond the price already given.
  final Widget? footnote;

  final VoidCallback? onPressed;
  final bool isLoading;

  const StickyBottomBar({
    super.key,
    this.price,
    this.priceLabel,
    this.priceCaption,
    this.secureNote,
    required this.buttonText,
    this.footnote,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (price != null) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (priceLabel != null)
                        Text(
                          priceLabel!,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      Text(
                        price!,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (priceCaption != null)
                        Text(
                          priceCaption!,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (secureNote != null) ...[
                // Flexible + FittedBox rather than a bare child: at a large
                // text scale on a narrow phone, "Secure by Razorpay" plus the
                // price and the button together are wider than the bar, and
                // this is the one piece that can give without losing meaning.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: secureNote!,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: price != null ? 1 : 0,
                child: SizedBox(
                  width: price == null ? double.infinity : null,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onPressed,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : Text(buttonText),
                  ),
                ),
              ),
            ],
          ),
          if (footnote != null) ...[
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: footnote!),
          ],
        ],
      ),
    );
  }
}
