import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/coaches_provider.dart';
import '../widgets/coach_card.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';

class CoachingScreen extends ConsumerStatefulWidget {
  const CoachingScreen({super.key});

  @override
  ConsumerState<CoachingScreen> createState() => _CoachingScreenState();
}

class _CoachingScreenState extends ConsumerState<CoachingScreen> {
  final _searchController = TextEditingController();

  /// What the provider is keyed on. Set on a debounce rather than on every
  /// keystroke, so typing a name does not fire a request per letter.
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Repaint at once so the clear button appears as the person types; only
    // the request that the provider is keyed on waits for the debounce.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = CoachQuery(search: _search.isEmpty ? null : _search);
    final coachesAsync = ref.watch(coachesProvider(query));

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: colors.card,
          onRefresh: () async => ref.invalidate(coachesProvider(query)),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Coaches',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Train with the best in your area',
                        style: TextStyle(
                            fontSize: 13, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              // Search — a real field now. It used to be a Text that looked
              // like an input and did nothing when tapped.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search coaches or sports…',
                      prefixIcon: Icon(Icons.search_rounded,
                          color: colors.textSecondary, size: 20),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              // How coaching works. The banner here used to promise a free
              // first session, which nothing in the product delivers.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          Colors.transparent
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.school_rounded,
                              color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pick a time, the coach confirms',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                      fontSize: 14)),
                              Text(
                                  'Your slot is held while your coach accepts.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Coaches list
              coachesAsync.when(
                loading: () => SliverToBoxAdapter(
                    child: ShimmerList(
                        count: 3, itemBuilder: () => const CoachCardShimmer())),
                error: (e, _) => SliverToBoxAdapter(
                    child: ErrorView(
                        message: apiErrorMessage(e,
                            fallback: 'Could not load coaches'),
                        onRetry: () => ref.invalidate(coachesProvider(query)))),
                data: (coaches) {
                  if (coaches.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text(
                              _search.isEmpty
                                  ? 'No coaches available yet.'
                                  : 'No coaches match "$_search".',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: colors.textSecondary, fontSize: 15)),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: coaches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => CoachCard(
                        coach: coaches[i],
                        onTap: () => context.push('/coaching/${coaches[i].id}'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
