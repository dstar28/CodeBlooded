import 'package:flutter/material.dart';

import '../../models/incident.dart';
import '../../models/trip.dart';
import '../../state/trip_store.dart';
import '../../theme/app_colors.dart';

/// Incident Details screen (Prompt #11).
///
/// Shows everything currently known about a single local [incident]:
/// type, description, automatically-recorded time, location (or its
/// absence), status, evidence count, an optional trip reference, and a
/// lifecycle timeline. Only entries that actually happened are ever shown
/// — this screen never fabricates admin verification, responder
/// assignment, or AI outcomes that haven't occurred.
class IncidentDetailsScreen extends StatelessWidget {
  const IncidentDetailsScreen({super.key, required this.incident});

  final Incident incident;

  Trip? get _trip {
    if (incident.tripId == null) return null;
    for (final trip in TripStore.instance.trips) {
      if (trip.id == incident.tripId) return trip;
    }
    return null;
  }

  String _locationLabel() {
    if (!incident.locationCaptured ||
        incident.latitude == null ||
        incident.longitude == null) {
      return 'Not captured';
    }
    final lat = incident.latitude!;
    final lng = incident.longitude!;
    final latSuffix = lat >= 0 ? 'N' : 'S';
    final lngSuffix = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}° $latSuffix, '
        '${lng.abs().toStringAsFixed(4)}° $lngSuffix';
  }

  String _evidenceLabel() {
    final count = incident.evidence.length;
    if (count == 0) return 'No evidence attached';
    if (count == 1) return '1 file';
    return '$count files';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trip = _trip;

    return Scaffold(
      appBar: AppBar(title: Text(incident.incidentId)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(incident: incident),
              const SizedBox(height: 20),
              Text('Details', style: textTheme.titleMedium),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _DetailRow(label: 'Type', value: incident.type.label),
                    const Divider(height: 1),
                    _DetailRow(
                      label: 'Time',
                      value: formatIncidentDateTime(incident.timestamp),
                    ),
                    const Divider(height: 1),
                    _DetailRow(label: 'Location', value: _locationLabel()),
                    const Divider(height: 1),
                    _DetailRow(label: 'Source', value: incident.source.label),
                    const Divider(height: 1),
                    _DetailRow(label: 'Evidence', value: _evidenceLabel()),
                    if (trip != null) ...[
                      const Divider(height: 1),
                      _DetailRow(label: 'Trip', value: trip.route),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Description', style: textTheme.titleMedium),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(incident.description, style: textTheme.bodyLarge),
              ),
              if (incident.evidence.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Evidence', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (final item in incident.evidence) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                item.type.icon,
                                color: AppColors.accent,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: textTheme.bodyLarge,
                                ),
                              ),
                              Text(
                                item.isVerified
                                    ? 'Verified'
                                    : (item.isUploaded
                                          ? 'Uploaded'
                                          : 'Local only'),
                                style: textTheme.bodyMedium?.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item != incident.evidence.last)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text('Timeline', style: textTheme.titleMedium),
              const SizedBox(height: 10),
              _TimelineCard(events: incident.timeline),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.incident});

  final Incident incident;

  Color get _statusColor {
    return incident.status == IncidentStatus.cancelled
        ? AppColors.textSecondary
        : AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(incident.type.icon, color: AppColors.accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(incident.type.label, style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Status: ', style: textTheme.bodyMedium),
                    Text(
                      incident.status.label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail row
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});

  final List<IncidentTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in events) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (event != events.last)
                      Container(
                        width: 2,
                        height: 32,
                        color: AppColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatIncidentClock(event.timestamp),
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(event.label, style: textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}