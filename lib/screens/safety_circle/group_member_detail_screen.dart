import 'package:flutter/material.dart';

import '../../models/safety_circle_group.dart';
import '../../theme/app_colors.dart';
import '../emergency/emergency_screen.dart';

/// View Member screen for a Safety Circle member (Prompt #9).
///
/// Shows only name, plain-language safety status, and a last-updated
/// label. Deliberately does NOT show phone number, exact/live GPS
/// coordinates, location history, or any other private profile data —
/// group membership does not grant unlimited access to another
/// traveler's information.
class GroupMemberDetailScreen extends StatelessWidget {
  const GroupMemberDetailScreen({super.key, required this.member});

  final SafetyCircleMember member;

  Color _statusColor(MemberSafetyStatus status) {
    switch (status) {
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
    final statusColor = _statusColor(member.status);
    final isDanger = member.status == MemberSafetyStatus.danger;

    return Scaffold(
      appBar: AppBar(title: const Text('Member Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        member.initials,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(member.name, style: textTheme.headlineMedium),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDanger
                        ? AppColors.danger.withOpacity(0.5)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Safety Status', style: textTheme.bodyMedium),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            member.status.label,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      member.status.descriptionFor(member.name),
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Last known status: ${member.lastUpdatedLabel}',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'For privacy, exact location, contact details, and '
                        'other personal information are not shared here.',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDanger) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmergencyScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emergency_outlined),
                  label: const Text('Emergency Assistance'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
