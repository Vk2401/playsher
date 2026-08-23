import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// The three reassurances at the foot of the home screen.
///
/// It is the last thing before the nav bar on purpose: a player who scrolled
/// past every venue without tapping one is usually hesitating about paying a
/// stranger for a pitch, and this is the answer to that.
class WhyBookStrip extends StatelessWidget {
  const WhyBookStrip({super.key});

  static const _reasons = <_Reason>[
    _Reason(
      icon: Icons.verified_user_outlined,
      title: 'Verified Venues',
      body: '100% safe & secure',
    ),
    _Reason(
      icon: Icons.calendar_month_outlined,
      title: 'Instant Booking',
      body: 'Quick & hassle-free',
    ),
    _Reason(
      icon: Icons.headset_mic_outlined,
      title: '24/7 Support',
      body: "We're here to help",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why book with us?',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _reasons.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    // Not a fixed height: at 1.3x text scale a hard-sized rule
                    // stops short of the text it is meant to separate.
                    constraints: const BoxConstraints(minHeight: 34),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    color: colors.border,
                  ),
                Expanded(child: _ReasonTile(reason: _reasons[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Reason {
  final IconData icon;
  final String title;
  final String body;

  const _Reason({required this.icon, required this.title, required this.body});
}

class _ReasonTile extends StatelessWidget {
  final _Reason reason;
  const _ReasonTile({required this.reason});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: '${reason.title}. ${reason.body}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(reason.icon, size: 18, color: colors.brandText),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reason.title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  reason.body,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: colors.textSecondary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
