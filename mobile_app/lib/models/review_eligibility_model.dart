/// Whether the signed-in customer may review a ground.
///
/// Asked before the form is offered, so nobody writes a review only to be told
/// it cannot be posted. [reason] lets the screen explain *why* rather than
/// silently hiding the button.
class ReviewEligibility {
  final bool canReview;

  /// `no_completed_booking` · `already_reviewed` · null when [canReview].
  final String? reason;
  final String? message;
  final int? bookingId;

  const ReviewEligibility({
    this.canReview = false,
    this.reason,
    this.message,
    this.bookingId,
  });

  /// What an unauthenticated or failed check resolves to: no form offered, no
  /// error shown. Never blocks the rest of the screen from rendering.
  static const unknown = ReviewEligibility();

  factory ReviewEligibility.fromJson(Map<String, dynamic> json) =>
      ReviewEligibility(
        canReview: json['can_review'] as bool? ?? false,
        reason: json['reason'] as String?,
        message: json['message'] as String?,
        bookingId: json['booking_id'] as int?,
      );

  bool get alreadyReviewed => reason == 'already_reviewed';
  bool get needsBooking => reason == 'no_completed_booking';
}
