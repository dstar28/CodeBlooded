import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../state/trip_store.dart';
import '../theme/app_colors.dart';
import '../routes/app_routes.dart';
import '../services/supabase/auth_repository.dart';
import '../utils/date_format.dart';
import '../widgets/app_bottom_nav.dart';
import 'emergency/emergency_screen.dart';
import 'trips/trip_details_screen.dart';
import 'live_safety_screen.dart';
import 'safety_circle/safety_circle_screen.dart';
import 'tourist_id/digital_tourist_id_screen.dart';

/// SafeGuard Home Dashboard.
///
/// This is the traveler's main screen. Everything on it is MOCK UI only:
/// no live location, no real AI risk scoring, and no real SOS backend.
/// Traveler-facing safety state is shown as a plain-language status
/// ("Safe" / "Caution" / "Warning" / "Emergency") — the numerical risk
/// score is an admin-only concept and must never appear here.
///
/// Visual language: clean light background, dark navy text, muted gray
/// secondary text, and a teal/green brand accent — matching the
/// SafeGuard reference UI. Active trip data comes from the existing
/// [TripStore] singleton; nothing here creates a second trip system.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Bottom nav order matches the SafeGuard reference shell:
  // Home | Safety | Group | Trip | Digital ID.
  static const int _homeIndex = 0;
  static const int _safetyIndex = 1;
  static const int _groupIndex = 2;
  static const int _tripIndex = 3;
  static const int _digitalIdIndex = 4;

  void _onNavTap(int index) {
    if (index == _homeIndex) return;

    switch (index) {
      case _safetyIndex:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LiveSafetyScreen()),
        );
        break;
      case _groupIndex:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SafetyCircleScreen()),
        );
        break;
      case _tripIndex:
        // Full Trip tab UI is out of scope for this pass; reuses the
        // existing placeholder-route architecture until it's built out.
        Navigator.of(context).pushNamed(AppRoutes.trips);
        break;
      case _digitalIdIndex:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DigitalTouristIdScreen()),
        );
        break;
    }
  }

  void _openEmergencyScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyScreen()),
    );
  }

  void _openTripDetail(Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of SafeGuard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Signs out of Supabase and clears the locally persisted "Remember
    // Me" session in one call (see AuthRepository.signOut).
    await AuthRepository.instance.signOut();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = TripStore.instance.trips;
    final activeTrip = trips.isNotEmpty ? trips.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeHeader(onLogout: _handleLogout),
              const SizedBox(height: 20),
              const _GreetingText(),
              const SizedBox(height: 16),
              const _SafetyStatusCard(),
              const SizedBox(height: 16),
              if (activeTrip != null)
                _ActiveTripCard(
                  trip: activeTrip,
                  onViewTrip: () => _openTripDetail(activeTrip),
                ),
              if (activeTrip != null) const SizedBox(height: 20),
              _QuickActionsSection(onSosTap: _openEmergencyScreen),
              const SizedBox(height: 20),
              const _SafetyAlertsSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _homeIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header (branding)
// ---------------------------------------------------------------------------

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onLogout});

  final VoidCallback onLogout;

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
          icon: Icons.person_outline,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
        ),
        const SizedBox(width: 10),
        _HeaderIconButton(
          icon: Icons.logout,
          onTap: onLogout,
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
// Greeting
// ---------------------------------------------------------------------------

class _GreetingText extends StatelessWidget {
  const _GreetingText();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Good morning,', style: textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text('Traveler', style: textTheme.headlineMedium),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Safety Status Card
// ---------------------------------------------------------------------------

class _SafetyStatusCard extends StatelessWidget {
  const _SafetyStatusCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.safeSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.safe.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield,
              color: AppColors.safe,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're Safe",
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All clear — no active alerts',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.safe,
                    fontWeight: FontWeight.w600,
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
// Active Trip Card
// ---------------------------------------------------------------------------

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip, required this.onViewTrip});

  final Trip trip;
  final VoidCallback onViewTrip;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isActive = trip.status == TripStatus.active;
    final statusColor = isActive ? AppColors.safe : AppColors.info;
    final statusSurface = isActive ? AppColors.safeSurface : AppColors.infoSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trip.status.label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            trip.name.toUpperCase(),
            style: textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(trip.route, style: textTheme.bodyMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                formatDateRange(trip.startDate, trip.endDate),
                style: textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onViewTrip,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text('View Trip'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Actions
// ---------------------------------------------------------------------------

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({required this.onSosTap});

  final VoidCallback onSosTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        // SOS is intentionally its own full-width danger-accent button so
        // it reads as clearly different from the routine actions below.
        _SosButton(onTap: onSosTap),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionTile(
                icon: Icons.card_travel_outlined,
                label: 'My Trips',
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.trips,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.groups_outlined,
                label: 'Safety Circle',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SafetyCircleScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.contact_phone_outlined,
                label: 'Emergency\nContacts',
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.emergency,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DigitalTouristIdTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DigitalTouristIdScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DigitalTouristIdTile extends StatelessWidget {
  const _DigitalTouristIdTile({required this.onTap});

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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                color: AppColors.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Digital Tourist ID',
                  style: textTheme.bodyLarge,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Row(
            children: [
              Icon(Icons.emergency_outlined, color: Colors.white, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Emergency',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.accent, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Safety Alerts
// ---------------------------------------------------------------------------

class _SafetyAlertsSection extends StatelessWidget {
  const _SafetyAlertsSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Safety Alerts', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
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
                    Icons.check_circle_outline,
                    color: AppColors.safe,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('No active alerts', style: textTheme.bodyLarge),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.info,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Stay aware of your surroundings while travelling.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}


