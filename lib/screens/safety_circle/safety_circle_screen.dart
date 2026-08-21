import 'package:flutter/material.dart';

import '../../models/safety_circle_group.dart';
import '../../state/safety_circle_store.dart';
import '../../theme/app_colors.dart';
import '../emergency/emergency_screen.dart';
import 'create_safety_circle_screen.dart';
import 'group_member_detail_screen.dart';
import 'join_safety_circle_screen.dart';

/// Safety Circle / Group Travel screen (Prompt #9).
///
/// This is local/mock group state only — there is no Supabase Realtime
/// sync, no real-time location sharing, no push notifications, and no AI
/// danger detection yet. The "Simulate Danger" control exists purely to
/// demonstrate the alert UI for this prompt and is clearly marked as a
/// demo control, not a production feature.
class SafetyCircleScreen extends StatefulWidget {
  const SafetyCircleScreen({super.key});

  @override
  State<SafetyCircleScreen> createState() => _SafetyCircleScreenState();
}

class _SafetyCircleScreenState extends State<SafetyCircleScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Circle')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: SafetyCircleStore.instance,
          builder: (context, _) {
            final group = SafetyCircleStore.instance.group;

            if (group == null) {
              return _EmptyCircleState(
                onCreate: _openCreateCircle,
                onJoin: _openJoinCircle,
              );
            }

            return _GroupDetailsView(
              group: group,
              onViewMember: _openMemberDetail,
              onEmergency: _openEmergencyScreen,
              onLeave: _confirmLeave,
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

class _EmptyCircleState extends StatelessWidget {
  const _EmptyCircleState({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
// Group details
// ---------------------------------------------------------------------------

class _GroupDetailsView extends StatelessWidget {
  const _GroupDetailsView({
    required this.group,
    required this.onViewMember,
    required this.onEmergency,
    required this.onLeave,
  });

  final SafetyCircleGroup group;
  final ValueChanged<SafetyCircleMember> onViewMember;
  final VoidCallback onEmergency;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final alertMemberId = SafetyCircleStore.instance.alertMemberId;
    final alertMember = alertMemberId == null
        ? null
        : SafetyCircleStore.instance.memberById(alertMemberId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          'Stay connected with the people travelling with you.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),

        if (alertMember != null) ...[
          _SafetyAlertBanner(
            member: alertMember,
            onViewMember: () => onViewMember(alertMember),
            onSos: onEmergency,
          ),
          const SizedBox(height: 20),
        ],

        // Group header card.
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
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.name, style: textTheme.titleMedium),
                        if (group.tripName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Trip: ${group.tripName}',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 14),
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
            ],
          ),
        ),

        const SizedBox(height: 24),
        Text('Members', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        ...group.members.map(
          (member) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MemberCard(
              member: member,
              onTap: member.isCurrentUser ? null : () => onViewMember(member),
            ),
          ),
        ),

        const SizedBox(height: 12),
        _DemoControlsSection(group: group),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onLeave,
          icon: const Icon(Icons.logout, color: AppColors.danger),
          label: const Text(
            'Leave Safety Circle',
            style: TextStyle(color: AppColors.danger),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.danger),
          ),
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
        color: AppColors.danger.withOpacity(0.10),
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

  Color get _statusColor {
    switch (member.status) {
      case MemberSafetyStatus.safe:
        return AppColors.accent;
      case MemberSafetyStatus.caution:
        return const Color(0xFFF5A524);
      case MemberSafetyStatus.danger:
        return AppColors.danger;
      case MemberSafetyStatus.offline:
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.isCurrentUser ? '${member.name} (You)' : member.name,
                      style: textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.status == MemberSafetyStatus.danger
                          ? member.status.descriptionFor(member.name)
                          : 'Updated ${member.lastUpdatedLabel}',
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
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
            ],
          ),
        ),
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
