import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../providers/favorites_provider.dart';
import '../widgets/ground_card.dart';
import '../widgets/error_view.dart';

class SavedTurfsScreen extends ConsumerWidget {
  const SavedTurfsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final favAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Saved Turfs')),
      body: favAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(favoritesProvider.notifier).load(),
        ),
        data: (grounds) {
          if (grounds.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colors.input,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_outline, size: 40, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text('No saved turfs yet.', style: TextStyle(color: colors.textSecondary, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text('Tap the heart on any turf to save it.', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Stats footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Text('${grounds.length} saved turfs', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: grounds.length,
                  itemBuilder: (_, i) => GroundCard(
                    ground: grounds[i],
                    isFavorite: true,
                    onFavoriteToggle: () =>
                        ref.read(favoritesProvider.notifier).toggle(grounds[i].id),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
