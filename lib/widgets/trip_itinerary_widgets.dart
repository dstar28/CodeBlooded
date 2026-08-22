import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../screens/emergency/emergency_screen.dart';
import '../screens/live_safety_screen.dart';
import '../screens/safety_circle/safety_circle_screen.dart';
import '../state/emergency_contacts_store.dart';
import '../state/safety_circle_store.dart';
import '../theme/app_colors.dart';

/// Shared presentation helpers + widgets for the Trips / Itinerary and
/// Trip Details screens (Part 2B-1).
///
/// [TripStatus] itself still only has the three real values already
/// defined on [Trip] (upcoming / active / completed) — the helpers below
/// only change how those same values are *worded and colored* to match
/// the reference UI ("On Track" instead of "Active"). Nothing here adds a
/// new trip state or a second trip data structure.
String tripStatusHeadline(TripStatus status) {
  switch (status) {
    case TripStatus.active:
      return 'On Track';
    case TripStatus.upcoming:
      return 'Upcoming';
    case TripStatus.completed:
      return 'Completed';
  }
}

String tripStatusDescription(TripStatus status) {
  switch (status) {
    case TripStatus.active:
      return 'All scheduled activities are progressing normally.';
    case TripStatus.upcoming:
      return 'This trip has not started yet.';
    case TripStatus.completed:
      return 'This trip has finished. Itinerary shown for reference.';
  }
}

Color tripStatusColor(TripStatus status) {
  switch (status) {
    case TripStatus.active:
      return AppColors.safe;
    case TripStatus.upcoming:
      return AppColors.info;
    case TripStatus.completed:
      return AppColors.textSecondary;
  }
}

/// Small status pill with a leading dot, matching the reference
/// Trip/Itinerary screenshot ("On Track" in a soft green pill).
class TripStatusPill extends StatelessWidget {
  const TripStatusPill({super.key, required this.status, this.dense = false});

  final TripStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = tripStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: dense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
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
            tripStatusHeadline(status),
            style: TextStyle(
              color: color,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One stop in a trip's itinerary timeline.
///
/// This is a display-only helper struct — it is not persisted anywhere
/// and is not a second [Trip] data model. [Trip] (see
/// lib/models/trip.dart) does not yet carry a real itinerary list, so
/// [buildDemoItinerary] derives a small, clearly-labelled sample timeline
/// from the trip's existing origin/destination fields, purely for
/// presentation. Swap this out once Trip Planning grows a real itinerary
/// field.
class TripItineraryStop {
  const TripItineraryStop({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
}

List<TripItineraryStop> buildDemoItinerary(Trip trip) {
  return [
    TripItineraryStop(
      time: '09:00',
      title: 'Hotel',
      subtitle: '${trip.origin} • Departure point',
      icon: Icons.apartment_outlined,
    ),
    TripItineraryStop(
      time: '11:00',
      title: 'Trek Start',
      subtitle: '${trip.destination} trailhead',
      icon: Icons.hiking,
    ),
    TripItineraryStop(
      time: '14:00',
      title: 'Waypoint',
      subtitle: '${trip.destination} viewpoint',
      icon: Icons.landscape_outlined,
    ),
    TripItineraryStop(
      time: '18:00',
      title: 'Return',
      subtitle: 'Back to ${trip.origin}',
      icon: Icons.home_outlined,
    ),
  ];
}

/// Vertical itinerary timeline: a connecting line with a dot per stop, an
/// icon avatar, the stop's time/title/subtitle, and a status pill —
/// matching the reference Trip/Itinerary screenshot.
class TripItineraryTimeline extends StatelessWidget {
  const TripItineraryTimeline({
    super.key,
    required this.stops,
    required this.status,
  });

  final List<TripItineraryStop> stops;
  final TripStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = tripStatusColor(status);

    return Column(
      children: [
        for (var i = 0; i < stops.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Expanded(
                        child: i == 0
                            ? const SizedBox.shrink()
                            : Container(
                                width: 2,
                                color: color.withOpacity(0.35),
                              ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == stops.length - 1
                              ? AppColors.surface
                              : color,
                          border: Border.all(color: color, width: 2),
                        ),
                      ),
                      Expanded(
                        child: i == stops.length - 1
                            ? const SizedBox.shrink()
                            : Container(
                                width: 2,
                                color: color.withOpacity(0.35),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(stops[i].icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      bottom: i == stops.length - 1 ? 4 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stops[i].time,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stops[i].title,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stops[i].subtitle,
                          style: textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TripStatusPill(status: status, dense: true),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Safety Monitoring" / "Safety Information" quick-links card.
///
/// Each row deep-links into an already-existing screen (Live Safety,
/// Group Safety Circle, Emergency Support) rather than standing up any
/// new GPS/realtime system. Status text is read from the real
/// [SafetyCircleStore] / [EmergencyContactsStore] singletons where
/// available instead of being invented.
class SafetyQuickLinksCard extends StatelessWidget {
  const SafetyQuickLinksCard({
    super.key,
    required this.trip,
    this.title = 'Safety Monitoring',
  });

  final Trip trip;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasGroup = SafetyCircleStore.instance.hasGroup;
    final hasContacts = EmergencyContactsStore.instance.contacts.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 12),
          _SafetyLinkRow(
            icon: Icons.shield_outlined,
            iconColor: tripStatusColor(trip.status),
            title: 'Current Status',
            value: tripStatusHeadline(trip.status),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LiveSafetyScreen(trip: trip)),
            ),
          ),
          const Divider(height: 24),
          _SafetyLinkRow(
            icon: Icons.location_on_outlined,
            iconColor: AppColors.info,
            title: 'Location Tracking',
            value: 'Open Safety tab',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LiveSafetyScreen(trip: trip)),
            ),
          ),
          const Divider(height: 24),
          _SafetyLinkRow(
            icon: Icons.groups_outlined,
            iconColor: AppColors.accent,
            title: 'Group Safety',
            value: hasGroup ? 'In a safety circle' : 'No group yet',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SafetyCircleScreen()),
            ),
          ),
          const Divider(height: 24),
          _SafetyLinkRow(
            icon: Icons.support_agent_outlined,
            iconColor: AppColors.danger,
            title: 'Emergency Support',
            value: hasContacts ? 'Contacts added' : 'Add a contact',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmergencyScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyLinkRow extends StatelessWidget {
  const _SafetyLinkRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}