import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';

/// The write-a-review form.
///
/// Only reached when the eligibility endpoint says this customer has played at
/// the ground — the server enforces the same rule, so this is about not wasting
/// someone's time, not about security.
///
/// Pops true once the review is posted, so the caller can refresh.
class WriteReviewSheet extends ConsumerStatefulWidget {
  final int groundId;
  final String groundName;

  const WriteReviewSheet({
    super.key,
    required this.groundId,
    required this.groundName,
  });

  static Future<bool> show(
    BuildContext context, {
    required int groundId,
    required String groundName,
  }) async {
    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // so the sheet rises above the keyboard
      backgroundColor: Colors.transparent,
      builder: (_) => WriteReviewSheet(
        groundId: groundId,
        groundName: groundName,
      ),
    );
    return posted ?? false;
  }

  @override
  ConsumerState<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<WriteReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_rating == 0) {
      setState(() => _error = 'Pick a rating first.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ApiClient.createReview(
        groundId: widget.groundId,
        rating: _rating,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = apiErrorMessage(e, fallback: 'Could not post your review');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      // Lifts the sheet clear of the soft keyboard so the comment field and the
      // submit button both stay visible while typing.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Rate this ground',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.groundName,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              _RatingPicker(
                rating: _rating,
                onChanged: (v) => setState(() {
                  _rating = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _comment,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What was the pitch, the facilities, the staff like?',
                  alignLabelWithHint: true,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  // Disabled while in flight: posting twice would be refused by
                  // the duplicate check, but with a confusing error.
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text(
                          'Post review',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _RatingPicker({required this.rating, required this.onChanged});

  static const _labels = [
    'Poor',
    'Below average',
    'Decent',
    'Good',
    'Excellent',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final value = i + 1;
            final filled = value <= rating;
            return Semantics(
              label: '$value star${value == 1 ? '' : 's'}',
              button: true,
              selected: filled,
              child: GestureDetector(
                onTap: () => onChanged(value),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: filled ? AppColors.star : colors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        // The rating is never conveyed by the star fill alone.
        Text(
          rating == 0 ? 'Tap to rate' : _labels[rating - 1],
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: rating == 0 ? colors.textSecondary : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
