import 'package:flutter/material.dart';
import '../../models/trip.dart';
import '../../state/emergency_contacts_store.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/trip_itinerary_widgets.dart';
import '../emergency/emergency_screen.dart';
import '../live_safety_screen.dart';

/// Trip Details screen.
///
/// Shows full info for a single [trip]: overview, trip status, itinerary,
/// safety information, and emergency support. "Start Trip" and "View
/// Safety" both open the Live Safety screen for this trip (Prompt #6) —
/// there is still no real background tracking wired up behind it yet.
class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({super.key, required this.trip});

  final Trip trip;

  void _openLiveSafety(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveSafetyScreen(trip: trip)),
    );
  }

  void _openEmergencySupport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isActive = trip.status == TripStatus.active;
    final primaryContact = EmergencyContactsStore.instance.primaryContact;
    final stops = buildDemoItinerary(trip);

    return Scaffold(
      appBar: AppBar(title: Text(trip.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trip overview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            trip.destination,
                            style: textTheme.headlineMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TripStatusPill(status: trip.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.alt_route,
                      label: 'Route',
                      value: trip.route,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Start Date',
                      value: formatFullDate(trip.startDate),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.event_outlined,
                      label: 'End Date',
                      value: formatFullDate(trip.endDate),
                    ),
                    const SizedBox(height: 12),
                    const _DetailRow(
                      icon: Icons.group_outlined,
                      label: 'Travelers',
                      value: 'You',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Trip status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip Status', style: textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Text(
                      tripStatusHeadline(trip.status),
                      style: TextStyle(
                        color: tripStatusColor(trip.status),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tripStatusDescription(trip.status),
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Itinerary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Itinerary', style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Sample itinerary based on this trip — for demo '
                      'purposes.',
                      style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TripItineraryTimeline(stops: stops, status: trip.status),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Safety information
              SafetyQuickLinksCard(
                trip: trip,
                title: 'Safety Information',
              ),
              const SizedBox(height: 16),

              // Emergency support
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.support_agent_outlined,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 10),
                        Text('Emergency Support', style: textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      primaryContact != null
                          ? 'Primary contact: ${primaryContact.name}'
                          : 'No emergency contact added yet.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openEmergencySupport(context),
                        icon: const Icon(Icons.emergency_outlined, color: AppColors.danger),
                        label: const Text(
                          'Open Emergency Support',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.danger.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes', style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      trip.notes.isEmpty
                          ? 'No notes added for this trip.'
                          : trip.notes,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _openLiveSafety(context),
                child: Text(isActive ? 'View Safety' : 'Start Trip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}