import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/map_links.dart';
import '../core/phone_links.dart';
import '../core/venue_contact.dart';

export '../core/venue_contact.dart';

/// Directions and Call, side by side, each shown only when the venue has the
/// data behind it. A venue with coordinates but no number gets one full-width
/// button, not a button beside a dead one.
class VenueContactBar extends StatelessWidget {
  final VenueContact contact;

  /// Whether to print the number itself under the buttons. On by default: the
  /// point of the row is contact *details*, and a player deciding whether to
  /// book wants to see a real number, not just trust that a button will dial
  /// one. Turn it off where the digits are already shown nearby.
  final bool showNumber;

  /// Filled rather than outlined — used where the row is the screen's own
  /// call to action instead of one affordance among many.
  final bool prominent;

  const VenueContactBar({
    super.key,
    required this.contact,
    this.showNumber = true,
    this.prominent = false,
  });

  Future<void> _open(
    BuildContext context,
    Future<bool> Function() action,
    String failure,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await action();
    if (opened) return;
    // The launch is the only thing that can fail here and it fails silently on
    // a device with no maps or dialer app — so say so rather than leaving the
    // tap looking unregistered.
    messenger.showSnackBar(SnackBar(content: Text(failure)));
  }

  @override
  Widget build(BuildContext context) {
    if (contact.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final number = contact.displayNumber;

    final buttons = <Widget>[
      if (contact.hasDirections)
        Expanded(
          child: _ContactButton(
            icon: Icons.directions_rounded,
            label: 'Directions',
            semanticLabel: 'Get directions to the venue',
            prominent: prominent,
            onPressed: () => _open(
              context,
              () => MapLinks.openDirections(
                latitude: contact.latitude,
                longitude: contact.longitude,
              ),
              'Could not open a maps app.',
            ),
          ),
        ),
      if (contact.hasDirections && contact.hasPhone)
        const SizedBox(width: 10),
      if (contact.hasPhone)
        Expanded(
          child: _ContactButton(
            icon: Icons.call_rounded,
            label: 'Call venue',
            semanticLabel: 'Call the venue on ${contact.callableNumber}',
            prominent: prominent,
            onPressed: () => _open(
              context,
              () => PhoneLinks.call(contact.phone),
              'Could not open the dialer.',
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: buttons),
        if (showNumber && number != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 14, color: colors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  number,
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final bool prominent;
  final VoidCallback onPressed;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.prominent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        // Flexible, not fixed: at 1.3x text scale "Directions" outgrows half a
        // narrow screen, and a clipped label is worse than an ellipsis.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      // 48 clears the 44px floor with room for the icon's own padding.
      child: SizedBox(
        height: 48,
        child: prominent
            ? FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: child,
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: child,
              ),
      ),
    );
  }
}
