import 'package:flutter/material.dart';

import '../../models/safety_circle_group.dart';
import '../../routes/app_routes.dart';
import '../../state/safety_circle_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_nav.dart';
import '../emergency/emergency_screen.dart';
import '../live_safety_screen.dart';
import '../tourist_id/digital_tourist_id_screen.dart';
import 'create_safety_circle_screen.dart';
import 'group_member_detail_screen.dart';
import 'join_safety_circle_screen.dart';

/// Group Safety Circle screen — the "Group" tab of SafeGuard's shared
/// bottom nav (Prompt #9, redesigned in Part 2A-2 to match the reference
/// visual).
///
/// This remains local/mock group state only — there is no Supabase
/// Realtime sync, no real-time GPS distance calculation, and no push
/// notifications. Member distance and "last updated" labels are demo
/// data for presentation purposes and are never presented as live GPS.
/// The "Simulate Danger" control exists purely to demonstrate the alert
/// UI for this prompt and is clearly marked as a demo control.
class SafetyCircleScreen extends StatefulWidget {
  const SafetyCircleScreen({super.key});

  @override
  State<SafetyCircleScreen> createState() => _SafetyCircleScreenState();
}

class _SafetyCircleScreenState extends State<SafetyCircleScreen> {
  // Shared bottom nav order: Home | Safety | Group | Trip | Digital ID.
  static const int _homeIndex = 0;
  static const int _safetyIndex = 1;
  static const int _groupIndex = 2;
  static const int _tripIndex = 3;
  static const int _digitalIdIndex = 4;

  void _onNavTap(int index) {
    if (index == _groupIndex) return;

    switch (index) {
      case _homeIndex:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case _safetyIndex:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LiveSafetyScreen()),
        );
        break;
      case _tripIndex:
        Navigator.of(context).pushNamed(AppRoutes.trips);
        break;
      case _digitalIdIndex:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DigitalTouristIdScreen()),
        );
        break;
    }
  }

  void _openCreateCircle() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateSafetyCircleScreen()),
    );
  }

  void _openJoinCircle() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JoinSafetyCircleScreen()),
    );
  }

  void _openMemberDetail(SafetyCircleMember member) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupMemberDetailScreen(member: member)),
    );
  }

  void _openEmergencyScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyScreen()),
    );
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Safety Circle?'),
        content: const Text(
          'You will stop receiving safety updates from this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      SafetyCircleStore.instance.leaveGroup();
    }
  }

  void _openGroupSettings(SafetyCircleGroup group) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group Settings', style: textTheme.titleMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Group Code', style: textTheme.bodyMedium),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      group.code,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _confirmLeave();
                  },
                  icon: const Icon(Icons.logout, color: AppColors.danger),
                  label: const Text(
                    'Leave Safety Circle',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: SafetyCircleStore.instance,
          builder: (context, _) {
            final group = SafetyCircleStore.instance.group;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _GroupHeader(
                    group: group,
                    onSettings: group == null
                        ? null
                        : () => _openGroupSettings(group),
                  ),
                ),
                Expanded(
                  child: group == null
                      ? _EmptyCircleState(
                          onCreate: _openCreateCircle,
                          onJoin: _openJoinCircle,
                        )
                      : _GroupDetailsView(
                          group: group,
                          onViewMember: _openMemberDetail,
                          onEmergency: _openEmergencyScreen,
                          onGroupSettings: () => _openGroupSettings(group),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _groupIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header (back arrow, title/subtitle, bell + settings)
// ---------------------------------------------------------------------------

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.onSettings});

  final SafetyCircleGroup? group;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = group?.tripName ?? group?.name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _HeaderIconButton(
          icon: Icons.arrow_back,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group Safety Circle', style: textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.notifications_none_outlined,
          showBadge: true,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
        ),
        const SizedBox(width: 10),
        _HeaderIconButton(
          icon: Icons.settings_outlined,
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: onTap == null
                    ? AppColors.textSecondary.withOpacity(0.4)
                    : AppColors.textPrimary,
                size: 20,
              ),
              if (showBadge)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyCircleState extends StatelessWidget {
  const _EmptyCircleState({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Stay connected with the people travelling with you.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          Center(
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
                    Icons.groups_outlined,
                    color: AppColors.accent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Safety Circle',
                  style: textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Create a group or join one to stay connected with your '
                    'travel companions.',
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create Safety Circle'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Join Safety Circle'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group summary helpers
// ---------------------------------------------------------------------------

class _GroupOverallStatus {
  const _GroupOverallStatus({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.surfaceColor,
  });

  final String label;
  final String subtitle;
  final Color color;
  final Color surfaceColor;

  static _GroupOverallStatus of(SafetyCircleGroup group) {
    final hasDanger = group.members.any(
      (m) => m.status == MemberSafetyStatus.danger,
    );
    final hasCaution = group.members.any(
      (m) => m.status == MemberSafetyStatus.caution,
    );
    final hasOffline = group.members.any(
      (m) => m.status == MemberSafetyStatus.offline,
    );

    if (hasDanger) {
      return const _GroupOverallStatus(
        label: 'Needs Help',
        subtitle: 'A member may be in danger',
        color: AppColors.danger,
        surfaceColor: AppColors.dangerSurface,
      );
    }
    if (hasCaution) {
      return const _GroupOverallStatus(
        label: 'Needs Attention',
        subtitle: 'A member may need attention',
        color: AppColors.warning,
        surfaceColor: AppColors.warningSurface,
      );
    }
    if (hasOffline) {
      return const _GroupOverallStatus(
        label: 'Some Offline',
        subtitle: 'One or more members are unreachable',
        color: AppColors.textSecondary,
        surfaceColor: AppColors.surfaceVariant,
      );
    }
    return const _GroupOverallStatus(
      label: 'All Safe',
      subtitle: 'Everyone is within range',
      color: AppColors.safe,
      surfaceColor: AppColors.safeSurface,
    );
  }
}

class _GroupSeparation {
  const _GroupSeparation({
    required this.label,
    required this.subtitle,
    required this.color,
  });

  final String label;
  final String subtitle;
  final Color color;

  static _GroupSeparation of(SafetyCircleGroup group) {
    final offlineCount = group.members
        .where((m) => m.status == MemberSafetyStatus.offline)
        .length;

    if (offlineCount > 0) {
      return _GroupSeparation(
        label: 'Signal Lost',
        subtitle: offlineCount == 1
            ? '1 member unreachable'
            : '$offlineCount members unreachable',
        color: AppColors.warning,
      );
    }

    final distances = group.members
        .where((m) => !m.isCurrentUser && m.distanceKm != null)
        .map((m) => m.distanceKm!)
        .toList();

    if (distances.isEmpty) {
      return const _GroupSeparation(
        label: 'Everyone within range',
        subtitle: 'Location sharing is off',
        color: AppColors.safe,
      );
    }

    final maxDistance = distances.reduce((a, b) => a > b ? a : b);
    return _GroupSeparation(
      label: 'Everyone within range',
      subtitle: 'Max distance: ${maxDistance.toStringAsFixed(1)} km',
      color: AppColors.safe,
    );
  }
}

Color _statusColor(MemberSafetyStatus status) {
  switch (status) {
    case MemberSafetyStatus.safe:
      return AppColors.safe;
    case MemberSafetyStatus.caution:
      return AppColors.warning;
    case MemberSafetyStatus.danger:
      return AppColors.danger;
    case MemberSafetyStatus.offline:
      return AppColors.textSecondary;
  }
}

// ---------------------------------------------------------------------------
// Group details
// ---------------------------------------------------------------------------

class _GroupDetailsView extends StatelessWidget {
  const _GroupDetailsView({
    required this.group,
    required this.onViewMember,
    required this.onEmergency,
    required this.onGroupSettings,
  });

  final SafetyCircleGroup group;
  final ValueChanged<SafetyCircleMember> onViewMember;
  final VoidCallback onEmergency;
  final VoidCallback onGroupSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final alertMemberId = SafetyCircleStore.instance.alertMemberId;
    final alertMember = alertMemberId == null
        ? null
        : SafetyCircleStore.instance.memberById(alertMemberId);
    final overall = _GroupOverallStatus.of(group);
    final separation = _GroupSeparation.of(group);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (alertMember != null) ...[
          _SafetyAlertBanner(
            member: alertMember,
            onViewMember: () => onViewMember(alertMember),
            onSos: onEmergency,
          ),
          const SizedBox(height: 16),
        ],

        // Summary card: member count / overall status | group separation.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SummaryColumn(
                    icon: Icons.groups_outlined,
                    iconColor: AppColors.accent,
                    label:
                        '${group.members.length} MEMBER${group.members.length == 1 ? '' : 'S'}',
                    valueText: overall.label,
                    valueColor: overall.color,
                    subtitle: overall.subtitle,
                  ),
                ),
                const VerticalDivider(width: 24),
                Expanded(
                  child: _SummaryColumn(
                    icon: Icons.shield_outlined,
                    iconColor: separation.color,
                    label: 'GROUP SEPARATION',
                    valueText: separation.label,
                    valueColor: separation.color,
                    subtitle: separation.subtitle,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'GROUP MEMBERS',
          style: textTheme.bodyMedium?.copyWith(
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...group.members.map(
          (member) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemberCard(
              member: member,
              onTap: member.isCurrentUser ? null : () => onViewMember(member),
            ),
          ),
        ),

        const SizedBox(height: 12),
        _GroupStatusCard(overall: overall),

        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Expanded(
              child: _InfoTile(
                icon: Icons.location_on_outlined,
                label: 'LOCATION SHARING',
                value: 'Emergency Only',
                description: 'Precise location is shared only during an '
                    'emergency.',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                icon: Icons.shield_outlined,
                label: 'SAFETY MONITORING',
                value: 'Active',
                description: "Monitoring everyone's safety in the "
                    'background.',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onGroupSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('GROUP SETTINGS'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: onEmergency,
                icon: const Icon(Icons.emergency_outlined),
                label: const Text('EMERGENCY HELP'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warningSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withOpacity(0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safety comes first',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'We will notify the group if any member may need '
                      'assistance.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _DemoControlsSection(group: group),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary column (used inside the top summary card)
// ---------------------------------------------------------------------------

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.valueText,
    required this.valueColor,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String valueText;
  final Color valueColor;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          valueText,
          style: textTheme.bodyLarge?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Safety Alert banner
// ---------------------------------------------------------------------------

class _SafetyAlertBanner extends StatelessWidget {
  const _SafetyAlertBanner({
    required this.member,
    required this.onViewMember,
    required this.onSos,
  });

  final SafetyCircleMember member;
  final VoidCallback onViewMember;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Safety Alert',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            MemberSafetyStatus.danger.descriptionFor(member.name),
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Check on ${member.name} or contact emergency assistance.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewMember,
                  child: const Text('View Member'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
                  onPressed: onSos,
                  child: const Text('SOS'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member card
// ---------------------------------------------------------------------------

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, this.onTap});

  final SafetyCircleMember member;
  final VoidCallback? onTap;

  String get _subtitleLine1 {
    if (member.isCurrentUser) return 'Current location';
    if (member.status == MemberSafetyStatus.offline) {
      return 'Offline • location unavailable';
    }
    if (member.distanceKm != null) {
      return 'In range • ${member.distanceKm!.toStringAsFixed(1)} km from you';
    }
    return 'In range';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _statusColor(member.status);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: member.status == MemberSafetyStatus.danger
                  ? AppColors.danger.withOpacity(0.5)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      member.initials,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
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
                            member.name,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member.isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.safeSurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'You',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.safe,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitleLine1,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!member.isCurrentUser) ...[
                      const SizedBox(height: 1),
                      Text(
                        'Last updated: ${member.lastUpdatedLabel}',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      member.status.label,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!member.isCurrentUser) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group Status card
// ---------------------------------------------------------------------------

class _GroupStatusCard extends StatelessWidget {
  const _GroupStatusCard({required this.overall});

  final _GroupOverallStatus overall;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overall.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: overall.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: overall.color.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.groups_outlined, color: overall.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Group Status', style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(overall.subtitle, style: textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: overall.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              overall.color == AppColors.safe
                  ? Icons.verified_user
                  : Icons.shield_outlined,
              color: overall.color,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location Sharing / Safety Monitoring info tile
// ---------------------------------------------------------------------------

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo controls (clearly marked, not a production feature)
// ---------------------------------------------------------------------------

class _DemoControlsSection extends StatelessWidget {
  const _DemoControlsSection({required this.group});

  final SafetyCircleGroup group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasDangerMember = group.members.any(
      (m) => m.status == MemberSafetyStatus.danger,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'DEMO CONTROLS',
                style: textTheme.bodyMedium?.copyWith(
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'For demonstration only. Not part of the real app experience — '
            'no real alerts or notifications are sent.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: hasDangerMember
                      ? null
                      : () => SafetyCircleStore.instance.simulateDanger(),
                  child: const Text('Simulate Danger'),
                ),
              ),
              if (hasDangerMember) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: SafetyCircleStore.instance.resetDemoStatuses,
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}