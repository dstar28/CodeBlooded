import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/trip.dart';
import '../routes/app_routes.dart';
import '../services/api/safeguard_api_client.dart';
import '../state/trip_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'safety_circle/safety_circle_screen.dart';
import 'tourist_id/digital_tourist_id_screen.dart';
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
/// exists yet, so this only ever reflects [safe] for real data. The other
/// two states can only be reached through the on-screen "Simulate Safety
/// Check (Demo)" control, which is clearly labelled as a presentation-only
/// demo and never wired to any real detection.
enum SafetyStatus { safe, caution, restricted }

extension _SafetyStatusPresentation on SafetyStatus {
  String get statusLabel {
    switch (this) {
      case SafetyStatus.safe:
        return 'Normal';
      case SafetyStatus.caution:
        return 'Caution';
      case SafetyStatus.restricted:
        return 'Restricted';
    }
  }

  String get badgeLabel {
    switch (this) {
      case SafetyStatus.safe:
        return 'All Clear';
      case SafetyStatus.caution:
        return 'Stay Alert';
      case SafetyStatus.restricted:
        return 'Take Action';
    }
  }

  Color get color {
    switch (this) {
      case SafetyStatus.safe:
        return AppColors.safe;
      case SafetyStatus.caution:
        return AppColors.warning;
      case SafetyStatus.restricted:
        return AppColors.danger;
    }
  }

  Color get surfaceColor {
    switch (this) {
      case SafetyStatus.safe:
        return AppColors.safeSurface;
      case SafetyStatus.caution:
        return AppColors.warningSurface;
      case SafetyStatus.restricted:
        return AppColors.dangerSurface;
    }
  }
}

/// Live Safety screen — the "Safety" tab of SafeGuard's shared bottom nav.
///
/// Shows the traveler's current plain-language safety status, a stylized
/// zone visualization (safe / caution / restricted areas) built from the
/// existing on-device location flow, and reference-style safety
/// information cards. There is no AI risk engine, no live geofencing
/// backend, and no new map package here — the zone map is a clearly
/// illustrative visual, and the "Simulate Safety Check" control is a
/// labelled demo-only affordance for presentation purposes.
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
  // Shared bottom nav order: Home | Safety | Group | Trip | Digital ID.
  static const int _homeIndex = 0;
  static const int _safetyIndex = 1;
  static const int _groupIndex = 2;
  static const int _tripIndex = 3;
  static const int _digitalIdIndex = 4;

  // Real safety state — always [safe] until a real detection backend
  // exists. Only the demo "Simulate Safety Check" control below can move
  // this, purely for presentation purposes.
  SafetyStatus _safetyStatus = SafetyStatus.safe;

  _LocationAccessState _accessState = _LocationAccessState.checking;
  Position? _position;
  bool _isPermanentlyDenied = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  // Active danger/warning/safe zones as a raw GeoJSON FeatureCollection,
  // fetched from the FastAPI backend (GET /zones/active) and handed to
  // the Leaflet map running inside the WebView. Null until the first
  // successful fetch; the map simply shows no zone overlays until then.
  Map<String, dynamic>? _zonesGeoJson;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadZones();
  }

  Future<void> _loadZones() async {
    final result = await SafeguardApiClient.instance.getActiveZones();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() => _zonesGeoJson = result.data);
    }
    // Silently ignore failures here — the map still shows the user's
    // location without zone overlays, and the zones list elsewhere on
    // this screen is unaffected.
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

  void _onNavTap(int index) {
    if (index == _safetyIndex) return;

    switch (index) {
      case _homeIndex:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case _groupIndex:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SafetyCircleScreen()),
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

  void _simulateSafetyCheck() {
    setState(() {
      switch (_safetyStatus) {
        case SafetyStatus.safe:
          _safetyStatus = SafetyStatus.caution;
          break;
        case SafetyStatus.caution:
          _safetyStatus = SafetyStatus.restricted;
          break;
        case SafetyStatus.restricted:
          _safetyStatus = SafetyStatus.safe;
          break;
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demo simulation only — no real safety change was detected.',
        ),
      ),
    );
  }

  void _showInfoSheet({
    required String title,
    required String body,
    required IconData icon,
    required Color color,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: 14),
              Text(body, style: textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                'Demo data shown for preview purposes.',
                style: textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
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
    final trip = _activeTrip;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SafeguardBrandHeader(),
              const SizedBox(height: 20),
              Text('Safety', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              _CurrentSafetyStatusCard(status: _safetyStatus),
              const SizedBox(height: 16),
              _buildMapSection(),
              const SizedBox(height: 16),
              _SafetyAdvisoryCard(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.warning,
                backgroundColor: AppColors.warningSurface,
                title: 'Weather Advisory',
                message: 'Heavy rain expected after 6 PM.',
                onTap: () => _showInfoSheet(
                  title: 'Weather Advisory',
                  body:
                      'Heavy rain is forecast for this area after 6 PM. '
                      'Trails may become slippery — plan to be back before '
                      'the rain sets in.',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 12),
              _SafetyAdvisoryCard(
                icon: Icons.info_outline,
                iconColor: AppColors.info,
                backgroundColor: AppColors.infoSurface,
                title: 'Local Guidance',
                message:
                    'Trail lighting is limited after sunset. Plan your '
                    'return before 18:30.',
                onTap: () => _showInfoSheet(
                  title: 'Local Guidance',
                  body:
                      'Trail lighting is limited after sunset in this area. '
                      'We recommend planning your return before 18:30 to '
                      'avoid low-visibility conditions.',
                  icon: Icons.info_outline,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(height: 20),
              if (trip != null) ...[
                _ActiveTripCard(
                  trip: trip,
                  onViewDetails: () => _openTripDetails(trip),
                ),
                const SizedBox(height: 20),
              ],
              _buildZonesSection(),
              const SizedBox(height: 16),
              _SimulateSafetyCheckTile(onTap: _simulateSafetyCheck),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _safetyIndex,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildMapSection() {
    switch (_accessState) {
      case _LocationAccessState.checking:
        return const _LocationCheckingCard();
      case _LocationAccessState.serviceDisabled:
        return _LocationMessageCard(
          icon: Icons.location_disabled_outlined,
          title: 'Location Services Disabled',
          message:
              'SafeGuard needs your location to show your position on the '
              'safety map.',
          buttonLabel: 'Open Settings',
          onPressed: _onOpenLocationSettings,
        );
      case _LocationAccessState.permissionDenied:
        return _LocationMessageCard(
          icon: Icons.location_off_outlined,
          title: 'Location Permission Required',
          message:
              'SafeGuard uses your location to show your position and '
              'nearby zones on the safety map.',
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
        return _SafetyZoneMap(
          position: _position,
          zonesGeoJson: _zonesGeoJson,
          isRefreshing: _isRefreshing,
          onRecenter: () {
            _fetchPosition();
            _loadZones();
          },
        );
    }
  }

  Widget _buildZonesSection() {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ZONES AROUND YOU',
          style: textTheme.bodyMedium?.copyWith(
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _ZoneTile(
          color: AppColors.safe,
          icon: Icons.park_outlined,
          title: 'Safe area',
          subtitle: 'Mawlynnong village trail',
          badgeLabel: 'Safe',
          badgeColor: AppColors.safe,
          badgeSurface: AppColors.safeSurface,
          onTap: () => _showInfoSheet(
            title: 'Safe area',
            body:
                'The Mawlynnong village trail is an active safe zone with '
                'good signal coverage and regular foot traffic.',
            icon: Icons.park_outlined,
            color: AppColors.safe,
          ),
        ),
        const SizedBox(height: 10),
        _ZoneTile(
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          title: 'Caution area',
          subtitle: 'River crossing • slippery rocks',
          badgeLabel: 'Caution',
          badgeColor: AppColors.warning,
          badgeSurface: AppColors.warningSurface,
          onTap: () => _showInfoSheet(
            title: 'Caution area',
            body:
                'The river crossing nearby has slippery rocks, especially '
                'after rain. Cross carefully and avoid it in low light.',
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(height: 10),
        _ZoneTile(
          color: AppColors.danger,
          icon: Icons.block_outlined,
          title: 'Restricted area',
          subtitle: 'Forest reserve • entry not permitted',
          badgeLabel: 'Emergency',
          badgeColor: AppColors.danger,
          badgeSurface: AppColors.dangerSurface,
          onTap: () => _showInfoSheet(
            title: 'Restricted area',
            body:
                'This forest reserve is off-limits to visitors. Entry is '
                'not permitted and may not be monitored for safety.',
            icon: Icons.block_outlined,
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Branding header (logo + bell + settings) — matches the Home dashboard
// look for a primary tab screen (no back button).
// ---------------------------------------------------------------------------

class _SafeguardBrandHeader extends StatelessWidget {
  const _SafeguardBrandHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accentDark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAFEGUARD',
                style: textTheme.titleMedium?.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Your Travel Guardian',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
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
  final VoidCallback onTap;
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
              Icon(icon, color: AppColors.textPrimary, size: 20),
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
// Current Safety Status
// ---------------------------------------------------------------------------

class _CurrentSafetyStatusCard extends StatelessWidget {
  const _CurrentSafetyStatusCard({required this.status});

  final SafetyStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = status.color;

    return _SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Safety Status', style: textTheme.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status.statusLabel,
                      style: textTheme.titleMedium?.copyWith(color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: status.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  status.badgeLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
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
// Shared soft card container
// ---------------------------------------------------------------------------

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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

    return _SoftCard(
      padding: const EdgeInsets.all(24),
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

    return _SoftCard(
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
// Safety zone map — real Leaflet map rendered in a WebView.
//
// Leaflet + tile rendering happen entirely in JavaScript
// (assets/map/leaflet_map.html); Flutter's only job is to load that page
// and push real GPS position + zone GeoJSON into it via
// WebViewController.runJavaScript. No geospatial math happens in Dart —
// point-in-zone / distance calculations live on the FastAPI backend.
// ---------------------------------------------------------------------------

class _SafetyZoneMap extends StatefulWidget {
  const _SafetyZoneMap({
    required this.position,
    required this.zonesGeoJson,
    required this.isRefreshing,
    required this.onRecenter,
  });

  final Position? position;
  final Map<String, dynamic>? zonesGeoJson;
  final bool isRefreshing;
  final VoidCallback onRecenter;

  @override
  State<_SafetyZoneMap> createState() => _SafetyZoneMapState();
}

class _SafetyZoneMapState extends State<_SafetyZoneMap> {
  late final WebViewController _controller;
  bool _pageReady = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _pageReady = true;
            _pushPosition();
            _pushZones();
          },
        ),
      )
      ..loadFlutterAsset('assets/map/leaflet_map.html');
  }

  @override
  void didUpdateWidget(covariant _SafetyZoneMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pageReady) return;
    if (widget.position != oldWidget.position) _pushPosition();
    if (widget.zonesGeoJson != oldWidget.zonesGeoJson) _pushZones();
  }

  void _pushPosition() {
    final position = widget.position;
    if (position == null) return;
    _controller.runJavaScript(
      'setUserLocation(${position.latitude}, ${position.longitude}, '
      '${position.accuracy})',
    );
  }

  void _pushZones() {
    final zones = widget.zonesGeoJson;
    if (zones == null) return;
    // Double-encode: jsonEncode(jsonEncode(...)) turns the GeoJSON object
    // into a single, safely-escaped JS string literal we can hand
    // straight to JSON.parse() on the page side.
    _controller.runJavaScript('setZones(${jsonEncode(jsonEncode(zones))})');
  }

  void _onRecenterTap() {
    widget.onRecenter();
    if (_pageReady) _controller.runJavaScript('recenter()');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 260,
            child: Stack(
              fit: StackFit.expand,
              children: [
                WebViewWidget(controller: _controller),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _RecenterButton(
                    isRefreshing: widget.isRefreshing,
                    onTap: _onRecenterTap,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 6,
              children: const [
                _ZoneLegendDot(color: AppColors.safe, label: 'Safe Area'),
                _ZoneLegendDot(color: AppColors.warning, label: 'Caution Area'),
                _ZoneLegendDot(color: AppColors.danger, label: 'Restricted Area'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.isRefreshing, required this.onTap});

  final bool isRefreshing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        onTap: isRefreshing ? null : onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : const Icon(
                  Icons.my_location,
                  size: 18,
                  color: AppColors.accentDark,
                ),
        ),
      ),
    );
  }
}

class _ZoneLegendDot extends StatelessWidget {
  const _ZoneLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Advisory cards (Weather / Local Guidance)
// ---------------------------------------------------------------------------

class _SafetyAdvisoryCard extends StatelessWidget {
  const _SafetyAdvisoryCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: iconColor.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(message, style: textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
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

    return _SoftCard(
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
// Zones list
// ---------------------------------------------------------------------------

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    required this.badgeSurface,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final Color badgeSurface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 18),
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
                              subtitle,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeSurface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ],
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
// Simulate Safety Check (demo)
// ---------------------------------------------------------------------------

class _SimulateSafetyCheckTile extends StatelessWidget {
  const _SimulateSafetyCheckTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.science_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulate Safety Check (Demo)',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This is a demo feature for presentation only.',
                      style: textTheme.bodyMedium,
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
        ),
      ),
    );
  }
}
