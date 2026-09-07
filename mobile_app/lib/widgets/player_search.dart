import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// The search field every player-finding surface uses.
///
/// Owns its controller and its debounce, so the two places that look for people
/// — the Find players screen and the invite sheet — cannot drift on how long
/// they wait or what they send. [onChanged] fires with the *settled* query, not
/// with every keystroke.
class PlayerSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  final bool enabled;
  final bool autofocus;

  const PlayerSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Username, name or full mobile number',
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  State<PlayerSearchField> createState() => _PlayerSearchFieldState();
}

class _PlayerSearchFieldState extends State<PlayerSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _settled = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTyped(String value) {
    _debounce?.cancel();
    // Redrawn immediately for the clear button; the query itself waits.
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final next = value.trim();
      if (next == _settled) return;
      _settled = next;
      widget.onChanged(next);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    _settled = '';
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return TextField(
      controller: _controller,
      onChanged: _onTyped,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      autocorrect: false,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        prefixIcon:
            Icon(Icons.search_rounded, size: 20, color: colors.textSecondary),
        suffixIcon: _controller.text.isEmpty
            ? null
            : Semantics(
                button: true,
                label: 'Clear search',
                child: GestureDetector(
                  onTap: _clear,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.close_rounded,
                        size: 18, color: colors.textSecondary),
                  ),
                ),
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

/// Why a player list is empty, said in the right words.
///
/// The case worth getting right is a **partial phone number**. The API matches
/// a number exactly and only exactly — that is what stops the endpoint being
/// walked to harvest accounts — so half a number matches nobody. Left to the
/// generic "nobody matched", that reads as "your friend isn't on Playsher",
/// which is both wrong and the kind of thing people repeat to each other.
class PlayerSearchEmpty extends StatelessWidget {
  /// Whether the list is empty because of a search, or because there was
  /// nothing to show before one.
  final bool searching;
  final String query;

  /// What to say when nothing has been typed yet.
  final String idleTitle;
  final String idleBody;

  const PlayerSearchEmpty({
    super.key,
    required this.searching,
    required this.query,
    required this.idleTitle,
    required this.idleBody,
  });

  /// Digits only, and not yet a whole Indian mobile number.
  static bool isPartialNumber(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;
    if (!RegExp(r'^\+?\d[\d\s-]*$').hasMatch(trimmed)) return false;
    return trimmed.replaceAll(RegExp(r'\D'), '').length < 10;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final partial = searching && isPartialNumber(query);

    final title = !searching
        ? idleTitle
        : partial
            ? 'Enter the full 10-digit number'
            : 'Nobody matched that';

    final body = !searching
        ? idleBody
        : partial
            ? 'A mobile number has to be complete to match — a partial one '
                'finds nobody.'
            : 'Check the username, or try their full mobile number.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searching ? Icons.person_search_rounded : Icons.groups_2_rounded,
            size: 44,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The heading above a result list, naming which list this is.
class PlayerListLabel extends StatelessWidget {
  final String label;

  const PlayerListLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: context.colors.textSecondary,
          ),
        ),
      );
}
