import 'package:flutter/material.dart';

import '../../models/incident.dart';
import '../../state/incident_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sync_status_badge.dart';
import 'incident_details_screen.dart';

/// Incident History screen (Prompt #11).
///
/// Lists the traveler's own previously-reported incidents from
/// [IncidentStore], most recent first. As of Prompt #12, each reported
/// incident is also persisted to Supabase in the background — the sync
/// status is shown in the app bar. Only the signed-in traveler's own
/// incidents are ever shown here.
class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key});

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    IncidentStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    IncidentStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _openDetails(Incident incident) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IncidentDetailsScreen(incident: incident),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidents = IncidentStore.instance.incidents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: SyncStatusBadge(
                state: IncidentStore.instance.syncState,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: incidents.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: incidents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final incident = incidents[index];
                  return _IncidentCard(
                    incident: incident,
                    onTap: () => _openDetails(incident),
                  );
                },
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                color: AppColors.accent,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text('No incidents reported', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Your reported incidents will appear here.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incident card
// ---------------------------------------------------------------------------

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.onTap});

  final Incident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  incident.type.icon,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            incident.incidentId,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(incident.type.label, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      formatIncidentDateTime(incident.timestamp),
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: incident.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = status == IncidentStatus.cancelled
        ? AppColors.textSecondary
        : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        textAlign: TextAlign.center,
        style: textTheme.bodyMedium?.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}