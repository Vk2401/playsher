import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/booking_model.dart';
import '../providers/bookings_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookingsAsync = ref.watch(bookingsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
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
                final upcoming = bookings.where((b) => b.isUpcoming).toList();
                final past = bookings.where((b) => b.isPast).toList();
                final cancelled = bookings.where((b) => b.isCancelled).toList();

                return TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _BookingList(
                        bookings: upcoming,
                        emptyMessage:
                            'No upcoming bookings.\nBook a ground to get started!'),
                    _BookingList(
                        bookings: past, emptyMessage: 'No past bookings yet.'),
                    _BookingList(
                        bookings: cancelled,
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

  const _BookingList({required this.bookings, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (bookings.isEmpty) {
      return Center(
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
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => context.push('/bookings/${bookings[i].id}'),
        child: BookingCard(booking: bookings[i]),
      ),
    );
  }
}
