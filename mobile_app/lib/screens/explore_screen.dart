import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/grounds_provider.dart';
import '../widgets/ground_card.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/error_view.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final String? initialSearch;
  const ExploreScreen({super.key, this.initialSearch});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _search;
  int? _sportId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialSearch ?? '';
    _search = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filter = GroundFilter(sportId: _sportId, search: _query);
    final grounds = ref.watch(groundsProvider(filter));
    final sports = ref.watch(sportsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Explore Turfs',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/venue-filter'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.input,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(Icons.tune_rounded,
                          size: 20, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colors.input,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search_rounded,
                        color: colors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        autofocus: widget.initialSearch != null,
                        style:
                            TextStyle(color: colors.textPrimary, fontSize: 14),
                        cursorColor: AppColors.primary,
                        decoration: InputDecoration(
                          hintText: 'Search grounds or sports\u2026',
                          hintStyle: TextStyle(
                              color: colors.textSecondary, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 18, color: colors.textSecondary),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      )
                    else
                      const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            // Category pills
            sports.maybeWhen(
              data: (list) => SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _FilterPill(
                      label: 'All Sports',
                      selected: _sportId == null,
                      onTap: () => setState(() => _sportId = null),
                    ),
                    ...list.map((s) => _FilterPill(
                          label: s.name,
                          selected: _sportId == s.id,
                          onTap: () => setState(
                              () => _sportId = _sportId == s.id ? null : s.id),
                        )),
                  ],
                ),
              ),
              orElse: () => const SizedBox(height: 44),
            ),
            const SizedBox(height: 12),
            // Results
            Expanded(
              child: grounds.when(
                loading: () => const ListShimmer(count: 4),
                error: (e, _) => ErrorView(
                  message:
                      apiErrorMessage(e, fallback: 'Could not load grounds'),
                  onRetry: () => ref.invalidate(groundsProvider(filter)),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'No grounds found.\nTry a different search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 15),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: list.length,
                    itemBuilder: (_, i) => GroundCard(ground: list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : colors.input,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
