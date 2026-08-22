import 'package:flutter/material.dart';

import '../services/supabase/sync_state.dart';
import '../theme/app_colors.dart';

/// Small status indicator for screens whose data is now backed by
/// Supabase (Prompt #12). Shows exactly what happened with the last save
/// attempt — it never claims a save succeeded when it didn't.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    if (state == SyncState.idle) return const SizedBox.shrink();

    late final String label;
    late final Color color;
    late final IconData icon;

    switch (state) {
      case SyncState.syncing:
        label = 'Syncing…';
        color = AppColors.textSecondary;
        icon = Icons.sync;
        break;
      case SyncState.synced:
        label = 'Synced';
        color = AppColors.accent;
        icon = Icons.cloud_done_outlined;
        break;
      case SyncState.offline:
        label = 'Offline Mode';
        color = AppColors.textSecondary;
        icon = Icons.cloud_off_outlined;
        break;
      case SyncState.error:
        label = 'Unable to sync';
        color = AppColors.danger;
        icon = Icons.error_outline;
        break;
      case SyncState.idle:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}