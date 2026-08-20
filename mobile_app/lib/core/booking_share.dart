/// Builds the plain-text summary a player sends to whoever is joining them.
///
/// Lives here rather than in a screen because two places share the same
/// booking — the confirmation right after paying, and the ticket they open
/// later — and a teammate should never receive two different descriptions of
/// the same slot.
///
/// Every field is optional: the confirmation screen assembles its values from
/// the create response, the detail screen from a BookingModel, and neither can
/// promise all of them. Nothing missing is printed as a dash — a line the
/// recipient cannot act on is worse than no line.
class BookingShare {
  const BookingShare._();

  static String build({
    String? reference,
    String? groundName,
    String? sportName,
    String? address,
    String? date,
    String? timeRange,
    String? duration,
    String? total,
    String? amountPaid,
    String? balanceDue,
    String? paymentMethod,
    String? directionsUrl,
  }) {
    final lines = <String>[];

    final what = [sportName, groundName].where(_present).join(' at ');
    lines.add(what.isEmpty ? 'Playsher booking' : '$what — booked!');
    lines.add('');

    void add(String label, String? value) {
      if (_present(value)) lines.add('$label: $value');
    }

    add('Date', date);
    add('Time', timeRange);
    add('Duration', duration);
    add('Venue', groundName);
    add('Address', address);
    add('Sport', sportName);

    // A recipient's first question is how to get there, so the link goes with
    // the address rather than at the bottom.
    if (_present(directionsUrl)) {
      lines.add('Directions: $directionsUrl');
    }

    // The reference is what the venue looks the booking up by, so it earns its
    // own block rather than being buried mid-list.
    if (_present(reference)) {
      lines.add('');
      lines.add('Booking ref: $reference');
    }

    final money = <String>[];
    if (_present(total)) money.add('Total: $total');
    if (_present(amountPaid)) money.add('Paid: $amountPaid');
    if (_present(balanceDue)) money.add('Due at venue: $balanceDue');
    if (_present(paymentMethod)) money.add('Payment: $paymentMethod');
    if (money.isNotEmpty) {
      lines.add('');
      lines.addAll(money);
    }

    lines.add('');
    lines.add('Booked with Playsher');

    return lines.join('\n');
  }

  static bool _present(String? value) =>
      value != null && value.trim().isNotEmpty && value.trim() != '—';
}
