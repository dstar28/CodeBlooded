import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/trip.dart';
import '../state/trip_store.dart';
import '../theme/app_colors.dart';
import 'trips/trip_details_screen.dart';

/// What the screen currently knows about device location access.
///
/// This only tracks permission/service state for the manual refresh flow
/// described in Prompt #6 — there is no background tracking, streaming,
/// or geo-fencing here.
enum _LocationAccessState {
  checking,
  serviceDisabled,
  permissionDenied,
  ready,
  error,
}

/// Plain-language, traveler-facing safety state.
///
/// This is intentionally NOT a numerical risk score — that is an
/// admin-only concept that must never surface here. No AI risk engine
/// exists yet, so the value is always [safe] for this prompt.
enum SafetyStatus { safe, caution, warning, emergency }

extension _SafetyStatusPresentation on SafetyStatus {
  String get headline {
    switch (this) {
      case SafetyStatus.safe:
        return "YOU'RE SAFE";
      case SafetyStatus.caution:
        return 'CAUTION';
      case SafetyStatus.warning:
        return 'WARNING';
      case SafetyStatus.emergency:
        return 'EMERGENCY';
    }
  }

  String get statusLabel {
    switch (this) {
      case SafetyStatus.safe:
        return 'All clear';
      case SafetyStatus.caution:
        return 'Caution';
      case SafetyStatus.warning:
        return 'Warning';
      case SafetyStatus.emergency:
        return 'Emergency';
    }
  }

  String get supportingText {
    switch (this) {
      case SafetyStatus.safe:
        return 'No immediate safety concerns detected.';
      case SafetyStatus.caution:
        return 'Stay alert and monitor your surroundings.';
      case SafetyStatus.warning:
        return 'Take precautions and stay reachable.';
      case SafetyStatus.emergency:
        return 'Seek assistance immediately.';
    }
  }

  IconData get icon {
    switch (this) {
      case SafetyStatus.safe:
        return Icons.shield_outlined;
      case SafetyStatus.caution:
        return Icons.info_outline;
      case SafetyStatus.warning:
        return Icons.warning_amber_outlined;
      case SafetyStatus.emergency:
        return Icons.emergency_outlined;
    }
  }

  Color get color {
    switch (this) {
      case SafetyStatus.safe:
        return AppColors.accent;
      case SafetyStatus.caution:
        return const Color(0xFFFFB74D);
      case SafetyStatus.warning:
        return const Color(0xFFFF8A65);
      case SafetyStatus.emergency:
        return AppColors.danger;
    }
  }
}

/// Live Safety & Location screen.
///
/// Shows the traveler's current plain-language safety status and current
/// device location (manual refresh only — no background/continuous
/// tracking, no geo-fencing, no AI risk scoring, no SOS backend). Location
/// stays local to the device; nothing here is uploaded anywhere.
///
/// If [trip] is not supplied, the screen falls back to the current active
/// trip from [TripStore], if any.
class LiveSafetyScreen extends StatefulWidget {
  const LiveSafetyScreen({super.key, this.trip});

  final Trip? trip;

  @override
  State<LiveSafetyScreen> createState() => _LiveSafetyScreenState();
}

class _LiveSafetyScreenState extends State<LiveSafetyScreen> {
  // Default state for this prompt — there is no AI risk engine yet.
  static const SafetyStatus _safetyStatus = SafetyStatus.safe;

  _LocationAccessState _accessState = _LocationAccessState.checking;
  Position? _position;
  bool _isPermanentlyDenied = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Trip? get _activeTrip {
    if (widget.trip != null) return widget.trip;
    for (final trip in TripStore.instance.trips) {
      if (trip.status == TripStatus.active) return trip;
    }
    return null;
  }

  Future<void> _initLocation() async {
    setState(() {
      _accessState = _LocationAccessState.checking;
      _errorMessage = null;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() => _accessState = _LocationAccessState.serviceDisabled);
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _accessState = _LocationAccessState.permissionDenied;
        _isPermanentlyDenied = permission == LocationPermission.deniedForever;
      });
      return;
    }

    await _fetchPosition();
  }

  Future<void> _fetchPosition() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _accessState = _LocationAccessState.ready;
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accessState = _LocationAccessState.error;
        _errorMessage = "We couldn't get your current location.";
        _isRefreshing = false;
      });
    }
  }

  void _onTryAgainPermission() {
    if (_isPermanentlyDenied) {
      Geolocator.openAppSettings();
    } else {
      _initLocation();
    }
  }

  void _onOpenLocationSettings() {
    Geolocator.openLocationSettings();
  }

  void _openTripDetails(Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = _activeTrip;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Safety')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LiveSafetyHeader(accessState: _accessState),
              const SizedBox(height: 20),
              _SafetyStatusCard(status: _safetyStatus),
              const SizedBox(height: 16),
              _buildLocationSection(),
              const SizedBox(height: 16),
              if (trip != null) ...[
                _ActiveTripCard(
                  trip: trip,
                  onViewDetails: () => _openTripDetails(trip),
                ),
                const SizedBox(height: 16),
              ],
              _SafetyInformationSection(accessState: _accessState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    switch (_accessState) {
      case _LocationAccessState.checking:
        return const _LocationCheckingCard();
      case _LocationAccessState.serviceDisabled:
        return _LocationMessageCard(
          icon: Icons.location_disabled_outlined,
          title: 'Location Services Disabled',
          message:
              'SafeGuard needs your location to provide travel safety '
              'information.',
          buttonLabel: 'Open Settings',
          onPressed: _onOpenLocationSettings,
        );
      case _LocationAccessState.permissionDenied:
        return _LocationMessageCard(
          icon: Icons.location_off_outlined,
          title: 'Location Permission Required',
          message:
              'SafeGuard uses your location to provide travel safety '
              'features.',
          buttonLabel: 'Try Again',
          onPressed: _onTryAgainPermission,
        );
      case _LocationAccessState.error:
        return _LocationMessageCard(
          icon: Icons.error_outline,
          title: 'Location Unavailable',
          message: _errorMessage ?? "We couldn't get your current location.",
          buttonLabel: 'Try Again',
          onPressed: _fetchPosition,
        );
      case _LocationAccessState.ready:
        return _LocationReadyCard(
          position: _position,
          isRefreshing: _isRefreshing,
          onRefresh: _fetchPosition,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _LiveSafetyHeader extends StatelessWidget {
  const _LiveSafetyHeader({required this.accessState});

  final _LocationAccessState accessState;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasLocation = accessState == _LocationAccessState.ready;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Safety', style: textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text(
                'Your current travel safety status',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (hasLocation ? AppColors.accent : AppColors.textSecondary)
                .withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasLocation
                    ? Icons.location_on_outlined
                    : Icons.location_searching,
                size: 14,
                color: hasLocation
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                hasLocation ? 'Located' : 'Locating',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasLocation
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Safety Status Card
// ---------------------------------------------------------------------------

class _SafetyStatusCard extends StatelessWidget {
  const _SafetyStatusCard({required this.status});

  final SafetyStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = status.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.headline, style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Status: ', style: textTheme.bodyMedium),
                    Text(
                      status.statusLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(status.supportingText, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location — checking
// ---------------------------------------------------------------------------

class _LocationCheckingCard extends StatelessWidget {
  const _LocationCheckingCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 14),
          Text('Checking location access…', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location — disabled / permission denied / error message card
// ---------------------------------------------------------------------------

class _LocationMessageCard extends StatelessWidget {
  const _LocationMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 28),
          const SizedBox(height: 12),
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location — ready (coordinates + map placeholder + refresh)
// ---------------------------------------------------------------------------

class _LocationReadyCard extends StatelessWidget {
  const _LocationReadyCard({
    required this.position,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final Position? position;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  String _formatLat(double lat) {
    final direction = lat >= 0 ? 'N' : 'S';
    return '${lat.abs().toStringAsFixed(4)}° $direction';
  }

  String _formatLng(double lng) {
    final direction = lng >= 0 ? 'E' : 'W';
    return '${lng.abs().toStringAsFixed(4)}° $direction';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pos = position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              Text('Current Location', style: textTheme.titleMedium),
              const SizedBox(height: 14),
              // Map area: no Google Maps configuration exists in this
              // project yet, so a polished placeholder stands in for it
              // rather than faking map functionality.
              Container(
                width: double.infinity,
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      color: AppColors.textSecondary,
                      size: 26,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'LIVE LOCATION MAP',
                      style: textTheme.bodyMedium?.copyWith(
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Waiting for map configuration',
                      style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CoordinateTile(
                      label: 'Latitude',
                      value: pos != null ? _formatLat(pos.latitude) : '—',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CoordinateTile(
                      label: 'Longitude',
                      value: pos != null ? _formatLng(pos.longitude) : '—',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isRefreshing ? null : onRefresh,
          icon: isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(isRefreshing ? 'Refreshing…' : 'Refresh Location'),
        ),
      ],
    );
  }
}

class _CoordinateTile extends StatelessWidget {
  const _CoordinateTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active Trip
// ---------------------------------------------------------------------------

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip, required this.onViewDetails});

  final Trip trip;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
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
              Text(
                'ACTIVE TRIP',
                style: textTheme.bodyMedium?.copyWith(
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Trip active',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(trip.route, style: textTheme.titleMedium),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewDetails,
              child: const Text('Trip Details'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Safety Information
// ---------------------------------------------------------------------------

class _SafetyInformationSection extends StatelessWidget {
  const _SafetyInformationSection({required this.accessState});

  final _LocationAccessState accessState;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final servicesEnabled =
        accessState != _LocationAccessState.serviceDisabled;
    final gpsAvailable = accessState == _LocationAccessState.ready;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Safety Information', style: textTheme.titleMedium),
        const SizedBox(height: 12),
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
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Location services',
                value: servicesEnabled ? 'Enabled' : 'Disabled',
                isPositive: servicesEnabled,
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.gps_fixed,
                label: 'GPS',
                value: gpsAvailable ? 'Available' : 'Unavailable',
                isPositive: gpsAvailable,
              ),
              const Divider(height: 1),
              const _InfoRow(
                icon: Icons.shield_outlined,
                label: 'Safety monitoring',
                value: 'Ready',
                isPositive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isPositive,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final valueColor = isPositive ? AppColors.accent : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: textTheme.bodyLarge)),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
