import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class StickyBottomBar extends StatelessWidget {
  final String? price;
  final String? priceLabel;
  final String buttonText;
  final VoidCallback? onPressed;
  final bool isLoading;

  const StickyBottomBar({
    super.key,
    this.price,
    this.priceLabel,
    required this.buttonText,
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
      child: Row(
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
                ],
              ),
            ),
            const SizedBox(width: 16),
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
    );
  }
}
