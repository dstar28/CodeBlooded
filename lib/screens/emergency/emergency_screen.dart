import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/emergency_contact.dart';
import '../../state/emergency_contacts_store.dart';
import '../../state/sos_store.dart';
import '../../theme/app_colors.dart';
import 'emergency_contacts_screen.dart';

/// Emergency Assistance / SOS screen.
///
/// This is UI and local interaction flow only (Prompt #7) — there is no
/// real emergency dispatch, no SMS, no calls, no responder backend, and
/// no blockchain involved. SOS state lives in [SosStore] for the current
/// app session only.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  static const int _countdownStart = 5;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  Timer? _countdownTimer;
  int _secondsLeft = _countdownStart;

  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  // Best-effort location snapshot for this screen only — fetched once,
  // never streamed. Permission is checked but never (re-)requested here;
  // Prompt #6's Live Safety screen owns that flow.
  bool _locationChecked = false;
  bool _locationAvailable = false;
  Position? _position;
  String _permissionStatusLabel = 'Checking…';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkLocation();

    if (SosStore.instance.status == SosStatus.active) {
      _startElapsedTimer();
    }

    SosStore.instance.addListener(_onSosStoreChanged);
    EmergencyContactsStore.instance.addListener(_onSosStoreChanged);
  }

  @override
  void dispose() {
    // Abandoning the screen mid-countdown must not leave a phantom
    // emergency behind — only a completed countdown creates one.
    if (SosStore.instance.status == SosStatus.countdown) {
      SosStore.instance.cancelCountdown();
    }
    SosStore.instance.removeListener(_onSosStoreChanged);
    EmergencyContactsStore.instance.removeListener(_onSosStoreChanged);
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onSosStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      if (!mounted) return;

      if (!serviceEnabled) {
        setState(() {
          _locationChecked = true;
          _locationAvailable = false;
          _permissionStatusLabel = 'Location services off';
        });
        return;
      }

      if (!granted) {
        setState(() {
          _locationChecked = true;
          _locationAvailable = false;
          _permissionStatusLabel = 'Permission not granted';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _locationChecked = true;
        _locationAvailable = true;
        _position = position;
        _permissionStatusLabel = 'Granted';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationChecked = true;
        _locationAvailable = false;
        _permissionStatusLabel = 'Unavailable';
      });
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _updateElapsed();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsed();
    });
  }

  void _updateElapsed() {
    final activatedAt = SosStore.instance.activatedAt;
    if (activatedAt == null) return;
    if (!mounted) return;
    setState(() => _elapsed = DateTime.now().difference(activatedAt));
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatCoordinate(double value, {required String positiveSuffix, required String negativeSuffix}) {
    final suffix = value >= 0 ? positiveSuffix : negativeSuffix;
    return '${value.abs().toStringAsFixed(4)}° $suffix';
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _onSosButtonTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Emergency Alert'),
        content: const Text(
          'You are about to activate an emergency alert.\n\n'
          'Your current safety information may be shared with authorized '
          'emergency contacts and responders when this feature is '
          'connected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Activate SOS'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _beginCountdown();
    }
  }

  void _beginCountdown() {
    SosStore.instance.startCountdown();
    setState(() => _secondsLeft = _countdownStart);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        SosStore.instance.activate();
        _startElapsedTimer();
        setState(() {});
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    SosStore.instance.cancelCountdown();
    setState(() {});
  }

  void _openManageContacts() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
    );
  }

  Future<void> _onCancelEmergencyTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Emergency?'),
        content: const Text(
          'Are you sure you want to cancel the active SOS?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Active'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel SOS'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _elapsedTimer?.cancel();
      SosStore.instance.cancelActive();
      setState(() {});
      // Return to the normal Emergency screen shortly after showing the
      // cancelled confirmation, matching the "short delay" allowance in
      // the spec — a manual "Done" action is also available below.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && SosStore.instance.status == SosStatus.cancelled) {
          SosStore.instance.acknowledgeCancelled();
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = SosStore.instance.status;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Assistance')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Get help quickly when you need it.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _buildStatusSection(status),
              const SizedBox(height: 24),
              _EmergencyInformationSection(
                contacts: EmergencyContactsStore.instance.contacts,
                primaryContact: EmergencyContactsStore.instance.primaryContact,
                onManageContacts: _openManageContacts,
                locationChecked: _locationChecked,
                locationAvailable: _locationAvailable,
                permissionStatusLabel: _permissionStatusLabel,
                position: _position,
                formatCoordinate: _formatCoordinate,
              ),
              const SizedBox(height: 20),
              const _SafetyMessageCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(SosStatus status) {
    switch (status) {
      case SosStatus.idle:
        return _IdleSosSection(
          pulseScale: _pulseScale,
          onTap: _onSosButtonTap,
        );
      case SosStatus.countdown:
        return _CountdownSection(
          secondsLeft: _secondsLeft,
          onCancel: _cancelCountdown,
        );
      case SosStatus.active:
        return _ActiveSosSection(
          pulseScale: _pulseScale,
          elapsedLabel: _formatElapsed(_elapsed),
          locationChecked: _locationChecked,
          locationAvailable: _locationAvailable,
          position: _position,
          formatCoordinate: _formatCoordinate,
          onCancelEmergency: _onCancelEmergencyTap,
        );
      case SosStatus.cancelled:
        return _CancelledSosSection(
          onDone: () {
            SosStore.instance.acknowledgeCancelled();
            setState(() {});
          },
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Idle — big SOS button
// ---------------------------------------------------------------------------

class _IdleSosSection extends StatelessWidget {
  const _IdleSosSection({required this.pulseScale, required this.onTap});

  final Animation<double> pulseScale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        ScaleTransition(
          scale: pulseScale,
          child: Material(
            color: AppColors.danger,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: AppColors.danger.withOpacity(0.6),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 168,
                height: 168,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emergency_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Hold for Emergency',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Countdown
// ---------------------------------------------------------------------------

class _CountdownSection extends StatelessWidget {
  const _CountdownSection({required this.secondsLeft, required this.onCancel});

  final int secondsLeft;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.danger.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            'SOS activating…',
            style: textTheme.titleMedium?.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '$secondsLeft',
              key: ValueKey<int>(secondsLeft),
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 64,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active SOS
// ---------------------------------------------------------------------------

class _ActiveSosSection extends StatelessWidget {
  const _ActiveSosSection({
    required this.pulseScale,
    required this.elapsedLabel,
    required this.locationChecked,
    required this.locationAvailable,
    required this.position,
    required this.formatCoordinate,
    required this.onCancelEmergency,
  });

  final Animation<double> pulseScale;
  final String elapsedLabel;
  final bool locationChecked;
  final bool locationAvailable;
  final Position? position;
  final String Function(double, {required String positiveSuffix, required String negativeSuffix}) formatCoordinate;
  final VoidCallback onCancelEmergency;

  String get _locationLabel {
    if (!locationChecked) return 'Checking…';
    if (!locationAvailable || position == null) return 'Location unavailable';
    final lat = formatCoordinate(
      position!.latitude,
      positiveSuffix: 'N',
      negativeSuffix: 'S',
    );
    final lng = formatCoordinate(
      position!.longitude,
      positiveSuffix: 'E',
      negativeSuffix: 'W',
    );
    return '$lat, $lng';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.danger.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              ScaleTransition(
                scale: pulseScale,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency_outlined,
                    color: AppColors.danger,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'SOS ACTIVE',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.danger,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Emergency assistance has been activated.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'For now, this is a local/mock emergency state only.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _StatusInfoRow(label: 'Status', value: 'Active', valueColor: AppColors.danger),
              const Divider(height: 24),
              _StatusInfoRow(label: 'Time', value: elapsedLabel),
              const Divider(height: 24),
              _StatusInfoRow(label: 'Location', value: _locationLabel),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: onCancelEmergency,
          child: const Text('Cancel Emergency'),
        ),
      ],
    );
  }
}

class _StatusInfoRow extends StatelessWidget {
  const _StatusInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: textTheme.bodyLarge)),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cancelled
// ---------------------------------------------------------------------------

class _CancelledSosSection extends StatelessWidget {
  const _CancelledSosSection({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.accent,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text('SOS Cancelled', style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'The emergency alert has been cancelled.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Emergency Information
// ---------------------------------------------------------------------------

class _EmergencyInformationSection extends StatelessWidget {
  const _EmergencyInformationSection({
    required this.contacts,
    required this.primaryContact,
    required this.onManageContacts,
    required this.locationChecked,
    required this.locationAvailable,
    required this.permissionStatusLabel,
    required this.position,
    required this.formatCoordinate,
  });

  final List<EmergencyContact> contacts;
  final EmergencyContact? primaryContact;
  final VoidCallback onManageContacts;
  final bool locationChecked;
  final bool locationAvailable;
  final String permissionStatusLabel;
  final Position? position;
  final String Function(double, {required String positiveSuffix, required String negativeSuffix}) formatCoordinate;

  String get _locationLabel {
    if (!locationChecked) return 'Checking…';
    if (!locationAvailable || position == null) return 'Location unavailable';
    final lat = formatCoordinate(
      position!.latitude,
      positiveSuffix: 'N',
      negativeSuffix: 'S',
    );
    final lng = formatCoordinate(
      position!.longitude,
      positiveSuffix: 'E',
      negativeSuffix: 'W',
    );
    return '$lat, $lng';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Emergency Contacts', style: textTheme.titleMedium),
            ),
            TextButton(
              onPressed: onManageContacts,
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _ContactsSummaryCard(
          contacts: contacts,
          primaryContact: primaryContact,
          onManageContacts: onManageContacts,
        ),
        const SizedBox(height: 20),
        Text('Current Location', style: textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _StatusInfoRow(
                label: 'Permission status',
                value: permissionStatusLabel,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _StatusInfoRow(label: 'Position', value: _locationLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Emergency Contacts summary (for the SOS screen only)
// ---------------------------------------------------------------------------

class _ContactsSummaryCard extends StatelessWidget {
  const _ContactsSummaryCard({
    required this.contacts,
    required this.primaryContact,
    required this.onManageContacts,
  });

  final List<EmergencyContact> contacts;
  final EmergencyContact? primaryContact;
  final VoidCallback onManageContacts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (contacts.isEmpty) {
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
            Row(
              children: [
                const Icon(
                  Icons.contact_phone_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No emergency contacts configured.',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onManageContacts,
                child: const Text('Manage Contacts'),
              ),
            ),
          ],
        ),
      );
    }

    final additionalContacts =
        contacts.where((c) => c.id != primaryContact?.id).toList();

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
          if (primaryContact != null) ...[
            Text(
              'Primary:',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(primaryContact!.name, style: textTheme.bodyLarge),
            Text(primaryContact!.phone, style: textTheme.bodyMedium),
            if (additionalContacts.isNotEmpty) const Divider(height: 24),
          ],
          for (final contact in additionalContacts) ...[
            Text(contact.name, style: textTheme.bodyLarge),
            Text(contact.phone, style: textTheme.bodyMedium),
            if (contact != additionalContacts.last)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Safety Message
// ---------------------------------------------------------------------------

class _SafetyMessageCard extends StatelessWidget {
  const _SafetyMessageCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
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
            Icons.info_outline,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'If you are in immediate danger, contact local emergency '
              'services when possible.',
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
