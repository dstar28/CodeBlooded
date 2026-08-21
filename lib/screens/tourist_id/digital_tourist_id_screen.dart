import 'package:flutter/material.dart';

import '../../models/tourist_credential.dart';
import '../../services/blockchain/blockchain_trust_service.dart';
import '../../services/credential_service.dart';
import '../../theme/app_colors.dart';

/// Digital Tourist ID screen (Prompt #10).
///
/// Shows a tourist's SafeGuard credential and lets them run a prototype
/// blockchain trust-registry verification against it. All blockchain
/// interaction goes through [CredentialService] — nothing here talks to
/// the mock registry directly.
///
/// This is UI + a local prototype trust registry only:
/// * No real government identity verification.
/// * No passport/Aadhaar data collected or shown.
/// * No live GPS, medical, or contact info anywhere on this screen.
/// * No numerical risk score.
class DigitalTouristIdScreen extends StatefulWidget {
  const DigitalTouristIdScreen({super.key});

  @override
  State<DigitalTouristIdScreen> createState() =>
      _DigitalTouristIdScreenState();
}

class _DigitalTouristIdScreenState extends State<DigitalTouristIdScreen> {
  final CredentialService _service = CredentialService.instance;
  bool _isVerifying = false;
  bool _isTogglingStatus = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _service.ensureIssued();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _verifyCredential() async {
    setState(() => _isVerifying = true);
    final result = await _service.verifyCredential();
    if (!mounted) return;
    setState(() => _isVerifying = false);
    if (result != null) {
      await _showVerificationResult(result);
    }
  }

  Future<void> _showVerificationResult(
    CredentialVerificationResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _VerificationResultDialog(result: result),
    );
  }

  Future<void> _toggleRevocation() async {
    setState(() => _isTogglingStatus = true);
    final credential = _service.credential;
    if (credential?.status == CredentialStatus.active) {
      await _service.revokeCredential();
    } else {
      await _service.reactivateCredential();
    }
    if (!mounted) return;
    setState(() => _isTogglingStatus = false);
  }

  @override
  Widget build(BuildContext context) {
    final credential = _service.credential;

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Tourist ID')),
      body: SafeArea(
        child: credential == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'A secure identity credential for safer travel.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    _TouristIdCard(credential: credential),
                    const SizedBox(height: 16),
                    _VerificationBadges(credential: credential),
                    const SizedBox(height: 20),
                    _QrReferenceSection(credential: credential),
                    const SizedBox(height: 20),
                    _CredentialDetailsSection(credential: credential),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isVerifying ? null : _verifyCredential,
                      icon: _isVerifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: Text(
                        _isVerifying ? 'Verifying…' : 'Verify Credential',
                      ),
                    ),
                    const SizedBox(height: 24),
                    _DemoControlsSection(
                      credential: credential,
                      isBusy: _isTogglingStatus,
                      onToggle: _toggleRevocation,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tourist ID card
// ---------------------------------------------------------------------------

class _TouristIdCard extends StatelessWidget {
  const _TouristIdCard({required this.credential});

  final TouristCredential credential;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isRevoked = credential.status == CredentialStatus.revoked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceVariant,
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isRevoked
              ? AppColors.danger.withOpacity(0.5)
              : AppColors.accent.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SafeGuard',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Digital Tourist ID',
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              _StatusPill(status: credential.status),
            ],
          ),
          const SizedBox(height: 24),
          Text('Name', style: textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            credential.touristName,
            style: textTheme.headlineMedium?.copyWith(fontSize: 22),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CardField(
                  label: 'Tourist Type',
                  value: credential.touristType.label,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CardField(
                  label: 'Credential Status',
                  value: credential.status.label,
                  valueColor: isRevoked ? AppColors.danger : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CardField(
            label: 'Credential ID',
            value: credential.credentialId,
            monospace: true,
          ),
        ],
      ),
    );
  }
}

class _CardField extends StatelessWidget {
  const _CardField({
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            fontSize: 15,
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: monospace ? FontWeight.w700 : null,
            letterSpacing: monospace ? 0.8 : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final CredentialStatus status;

  @override
  Widget build(BuildContext context) {
    final isRevoked = status == CredentialStatus.revoked;
    final color = isRevoked ? AppColors.danger : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verification badges
// ---------------------------------------------------------------------------

class _VerificationBadges extends StatelessWidget {
  const _VerificationBadges({required this.credential});

  final TouristCredential credential;

  @override
  Widget build(BuildContext context) {
    final isActive = credential.status == CredentialStatus.active;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Badge(
          icon: isActive ? Icons.check_circle : Icons.error_outline,
          label: isActive ? 'Credential Verified' : 'Credential Revoked',
          color: isActive ? AppColors.accent : AppColors.danger,
        ),
        const _Badge(
          icon: Icons.link,
          label: 'Blockchain Registered',
          color: AppColors.accent,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QR-style reference section
// ---------------------------------------------------------------------------

class _QrReferenceSection extends StatelessWidget {
  const _QrReferenceSection({required this.credential});

  final TouristCredential credential;

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
        children: [
          Container(
            width: 128,
            height: 128,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              painter: _QrPatternPainter(seed: credential.credentialId),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            credential.credentialId,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Demo QR representation — encodes only this reference ID for '
            'an authorized verifier. No personal data is embedded.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Purely decorative, deterministic grid that visually resembles a QR
/// code. This does NOT encode scannable data — no QR package is added
/// for this prototype, per scope. The credential ID is shown as plain
/// text alongside it for anyone who needs the actual reference.
class _QrPatternPainter extends CustomPainter {
  _QrPatternPainter({required String seed}) : _seedValue = seed.hashCode;

  final int _seedValue;

  @override
  void paint(Canvas canvas, Size size) {
    const gridCount = 9;
    final cellSize = size.width / gridCount;
    final paint = Paint()..color = const Color(0xFF0A0E1A);

    var state = _seedValue;
    int next() {
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      return state;
    }

    for (var row = 0; row < gridCount; row++) {
      for (var col = 0; col < gridCount; col++) {
        final isFinderCorner = (row < 3 && col < 3) ||
            (row < 3 && col >= gridCount - 3) ||
            (row >= gridCount - 3 && col < 3);
        final filled = isFinderCorner
            ? (row == 0 ||
                row == 2 ||
                col == 0 ||
                col == 2 ||
                (row == 1 && col == 1))
            : next() % 2 == 0;

        if (filled) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize,
              row * cellSize,
              cellSize * 0.92,
              cellSize * 0.92,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPatternPainter oldDelegate) =>
      oldDelegate._seedValue != _seedValue;
}

// ---------------------------------------------------------------------------
// Credential details
// ---------------------------------------------------------------------------

class _CredentialDetailsSection extends StatelessWidget {
  const _CredentialDetailsSection({required this.credential});

  final TouristCredential credential;

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
          Text('Credential Details', style: textTheme.titleMedium),
          const SizedBox(height: 14),
          _DetailRow(label: 'Issuer', value: credential.issuerName),
          _DetailRow(label: 'Credential ID', value: credential.credentialId),
          const _DetailRow(label: 'Issued', value: 'Today'),
          _DetailRow(label: 'Status', value: credential.status.label),
          const _DetailRow(label: 'Blockchain', value: 'Registered'),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: textTheme.bodyMedium),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: textTheme.bodyLarge?.copyWith(fontSize: 14.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verification result dialog
// ---------------------------------------------------------------------------

class _VerificationResultDialog extends StatelessWidget {
  const _VerificationResultDialog({required this.result});

  final CredentialVerificationResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isValid = result.isValid;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Icon(
            isValid ? Icons.verified_outlined : Icons.error_outline,
            color: isValid ? AppColors.accent : AppColors.danger,
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Credential Verification')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResultRow(label: 'Credential', value: result.credentialId),
          _ResultRow(
            label: 'Status',
            value: result.status == CredentialStatus.active
                ? 'VALID'
                : 'REVOKED',
            valueColor:
                result.status == CredentialStatus.active
                    ? AppColors.accent
                    : AppColors.danger,
          ),
          _ResultRow(
            label: 'Blockchain Registry',
            value: result.registryMatched ? 'MATCHED' : 'NOT FOUND',
            valueColor:
                result.registryMatched ? AppColors.accent : AppColors.danger,
          ),
          _ResultRow(
            label: 'Credential Integrity',
            value: result.integrityValid ? 'VALID' : 'INVALID',
            valueColor:
                result.integrityValid ? AppColors.accent : AppColors.danger,
          ),
          const SizedBox(height: 14),
          Text(
            'This is a prototype verification result from the demo trust '
            'registry. It does not verify government identity documents.',
            style: textTheme.bodyMedium?.copyWith(fontSize: 12.5),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 14,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo controls
// ---------------------------------------------------------------------------

class _DemoControlsSection extends StatelessWidget {
  const _DemoControlsSection({
    required this.credential,
    required this.isBusy,
    required this.onToggle,
  });

  final TouristCredential credential;
  final bool isBusy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isActive = credential.status == CredentialStatus.active;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.build_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Demo Controls',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'For prototype testing only — simulates the registry marking '
            'this credential revoked or active again.',
            style: textTheme.bodyMedium?.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onToggle,
            style: OutlinedButton.styleFrom(
              foregroundColor: isActive ? AppColors.danger : AppColors.accent,
              side: BorderSide(
                color: (isActive ? AppColors.danger : AppColors.accent)
                    .withOpacity(0.5),
              ),
            ),
            icon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isActive ? Icons.block : Icons.restore),
            label: Text(
              isActive ? 'Revoke Credential' : 'Restore to Active',
            ),
          ),
        ],
      ),
    );
  }
}
