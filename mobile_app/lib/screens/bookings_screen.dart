import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/booking_model.dart';
import '../providers/bookings_provider.dart';
import '../widgets/app_back_button.dart';
import '../widgets/booking_card.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(bookingsProvider);
    await ref.read(bookingsProvider.future);
  }

  /// Most recently made booking first. `created_at` is the real answer; the id
  /// is the tiebreak and the fallback when the payload omitted the timestamp.
  static List<BookingModel> _newestFirst(List<BookingModel> bookings) {
    final list = [...bookings];
    list.sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at != null && bt != null && at != bt) return bt.compareTo(at);
      return b.id.compareTo(a.id);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookingsAsync = ref.watch(bookingsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        // Reached with context.go from the confirmation screen, which leaves
        // nothing to pop — without an explicit fallback the arrow never appears
        // and system back closes the app.
        leading: const AppBackButton(),
        title: const Text('My Bookings'),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.primary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
            dividerColor: colors.border,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
              Tab(text: 'Cancelled'),
            ],
          ),
          Expanded(
            child: bookingsAsync.when(
              loading: () => ShimmerList(
                  count: 4, itemBuilder: () => const BookingCardShimmer()),
              error: (e, _) => ErrorView(
                message: apiErrorMessage(e,
                    fallback: 'Could not load your bookings'),
                onRetry: () => ref.invalidate(bookingsProvider),
              ),
              data: (bookings) {
                // The API already orders newest-first; re-sorting here keeps
                // that true if a cached or differently-ordered payload arrives.
                final ordered = _newestFirst(bookings);
                final upcoming = ordered.where((b) => b.isUpcoming).toList();
                final past = ordered.where((b) => b.isPast).toList();
                final cancelled = ordered.where((b) => b.isCancelled).toList();

                return TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _BookingList(
                        bookings: upcoming,
                        onRefresh: _refresh,
                        emptyMessage:
                            'No upcoming bookings.\nBook a ground to get started!'),
                    _BookingList(
                        bookings: past,
                        onRefresh: _refresh,
                        emptyMessage: 'No past bookings yet.'),
                    _BookingList(
                        bookings: cancelled,
                        onRefresh: _refresh,
                        emptyMessage: 'No cancelled bookings.'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _BookingList({
    required this.bookings,
    required this.emptyMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (bookings.isEmpty) {
      // Still scrollable, so an empty tab can be pulled to refresh too.
      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: colors.card,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
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
                child: Icon(Icons.event_note_rounded,
                    size: 40, color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: colors.card,
      onRefresh: onRefresh,
      // BookingCard owns its own tap; wrapping it in a second GestureDetector
      // stacked two handlers on the same press.
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) => BookingCard(booking: bookings[i]),
      ),
    );
  }
}
