import 'package:flutter/material.dart';
import '../../models/trip.dart';
import '../../state/trip_store.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/sync_status_badge.dart';
import '../live_safety_screen.dart';
import '../safety_circle/safety_circle_screen.dart';
import '../tourist_id/digital_tourist_id_screen.dart';
import 'create_trip_screen.dart';
import 'trip_details_screen.dart';

/// Trips tab — trip list, empty state, and entry point to Create Trip /
/// Trip Details.
///
/// Trip data comes from [TripStore], an in-memory/mock singleton. As of
/// Prompt #12, [TripStore] also persists new trips to Supabase in the
/// background; this screen shows the resulting [SyncStatusBadge] next to
/// the header so the traveler can see Synced / Offline Mode / Unable to
/// sync without any other layout changes.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  // Bottom nav order matches the SafeGuard reference shell:
  // Home | Safety | Group | Trip | Digital ID.
  static const int _homeIndex = 0;
  static const int _safetyIndex = 1;
  static const int _groupIndex = 2;
  static const int _tripsIndex = 3;
  static const int _digitalIdIndex = 4;

  void _onNavTap(int index) {
    if (index == _tripsIndex) return;

    switch (index) {
      case _homeIndex:
        // Trips is always pushed on top of Home, so popping back to the
        // first route returns to the dashboard without pushing a new one.
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case _safetyIndex:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LiveSafetyScreen()),
        );
        break;
      case _groupIndex:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SafetyCircleScreen()),
        );
        break;
      case _digitalIdIndex:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DigitalTouristIdScreen()),
        );
        break;
    }
  }

  void _openCreateTrip() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateTripScreen()),
    );
  }

  void _openTripDetails(Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Trips', style: textTheme.headlineMedium),
                  AnimatedBuilder(
                    animation: TripStore.instance,
                    builder: (context, _) => SyncStatusBadge(
                      state: TripStore.instance.syncState,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Plan and manage your journeys.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openCreateTrip,
                icon: const Icon(Icons.add),
                label: const Text('Plan a Trip'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedBuilder(
                  animation: TripStore.instance,
                  builder: (context, _) {
                    final trips = TripStore.instance.trips;

                    if (trips.isEmpty) {
                      return _EmptyTripsState(onPlanTrip: _openCreateTrip);
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: trips.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        return _TripCard(
                          trip: trip,
                          onTap: () => _openTripDetails(trip),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _tripsIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyTripsState extends StatelessWidget {
  const _EmptyTripsState({required this.onPlanTrip});

  final VoidCallback onPlanTrip;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.card_travel_outlined,
                color: AppColors.accent,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No trips planned',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Plan your next journey and keep your travel information '
              'organized.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onPlanTrip,
              icon: const Icon(Icons.add),
              label: const Text('Plan a Trip'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trip card
// ---------------------------------------------------------------------------

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  Color get _statusColor {
    switch (trip.status) {
      case TripStatus.active:
        return AppColors.accent;
      case TripStatus.upcoming:
      case TripStatus.completed:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _statusColor;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.destination,
                      style: textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: trip.status, color: statusColor),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.alt_route,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trip.route,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatDateRange(trip.startDate, trip.endDate),
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final TripStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}