import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/incident.dart';
import '../../models/trip.dart';
import '../../state/incident_store.dart';
import '../../state/trip_store.dart';
import '../../theme/app_colors.dart';
import 'incident_details_screen.dart';
import 'incident_history_screen.dart';

/// What the Report Incident screen currently knows about device location
/// access for the incident being drafted.
///
/// This is a one-off manual capture for a single incident report — there
/// is no background/continuous tracking here, mirroring the manual
/// refresh-only approach already used by Live Safety (Prompt #6).
enum _LocationCaptureState { idle, capturing, captured, unavailable }

/// Report an Incident screen (Prompt #11).
///
/// Lets a traveler create a local incident report: type, description,
/// an optional one-off current-location capture, local evidence
/// selection, and an automatically-recorded timestamp. Submitting only
/// stores the incident in [IncidentStore] for the current app session —
/// there is no Supabase persistence, AI detection, admin verification, or
/// blockchain write behind this yet.
class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  static const int _minDescriptionLength = 10;

  IncidentType? _selectedType;

  _LocationCaptureState _locationState = _LocationCaptureState.idle;
  Position? _position;

  final List<IncidentEvidenceItem> _evidence = [];
  int _evidenceCounter = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Trip? get _activeTrip {
    for (final trip in TripStore.instance.trips) {
      if (trip.status == TripStatus.active) return trip;
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Incident type
  // -------------------------------------------------------------------

  Future<void> _pickType() async {
    final selected = await showModalBottomSheet<IncidentType>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _IncidentTypeSheet(selectedType: _selectedType),
    );

    if (selected != null) {
      setState(() => _selectedType = selected);
    }
  }

  // -------------------------------------------------------------------
  // Location
  // -------------------------------------------------------------------

  Future<void> _captureLocation() async {
    setState(() => _locationState = _LocationCaptureState.capturing);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _locationState = _LocationCaptureState.unavailable);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locationState = _LocationCaptureState.unavailable);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _position = position;
        _locationState = _LocationCaptureState.captured;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationState = _LocationCaptureState.unavailable);
    }
  }

  // -------------------------------------------------------------------
  // Evidence (local selection UI only — no file upload)
  // -------------------------------------------------------------------

  Future<void> _addEvidence() async {
    final type = await showModalBottomSheet<EvidenceType>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _EvidenceTypeSheet(),
    );

    if (type == null) return;

    _evidenceCounter += 1;
    setState(() {
      _evidence.add(
        IncidentEvidenceItem(
          id: 'local-evidence-$_evidenceCounter',
          type: type,
          label: '${type.label} $_evidenceCounter',
          addedAt: DateTime.now(),
        ),
      );
    });
  }

  void _removeEvidence(IncidentEvidenceItem item) {
    setState(() => _evidence.removeWhere((e) => e.id == item.id));
  }

  // -------------------------------------------------------------------
  // Submission
  // -------------------------------------------------------------------

  String? _validateDescription(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please describe what happened';
    }
    if (trimmed.length < _minDescriptionLength) {
      return 'Please add a few more details';
    }
    return null;
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final type = _selectedType;

    if (type == null) {
      setState(() {}); // surface the "select a type" hint below the field
    }

    if (!formValid || type == null) return;

    final trip = _activeTrip;

    final incident = IncidentStore.instance.createIncident(
      type: type,
      description: _descriptionController.text.trim(),
      latitude: _position?.latitude,
      longitude: _position?.longitude,
      locationCaptured: _locationState == _LocationCaptureState.captured,
      tripId: trip?.id,
      evidence: List.unmodifiable(_evidence),
    );

    if (!mounted) return;
    await _showConfirmation(incident);
  }

  Future<void> _showConfirmation(Incident incident) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Incident Reported'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident ID',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              incident.incidentId,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 12),
            Text('Status', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              incident.status.label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => IncidentDetailsScreen(incident: incident),
                ),
              );
            },
            child: const Text('View Incident'),
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const IncidentHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Incident'),
        actions: [
          IconButton(
            tooltip: 'Incident History',
            icon: const Icon(Icons.history),
            onPressed: _openHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tell us what happened so the right assistance can be '
                  'provided.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Text('Incident Type', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                _TypeSelectorField(
                  selectedType: _selectedType,
                  onTap: _pickType,
                ),
                if (_selectedType == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Select the type that best matches what happened.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('What happened?', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  minLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Describe what happened...',
                  ),
                  validator: _validateDescription,
                ),
                const SizedBox(height: 24),
                Text('Incident Location', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                _LocationSection(
                  state: _locationState,
                  position: _position,
                  onCapture: _captureLocation,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text('Add Evidence', style: textTheme.titleMedium),
                    ),
                    TextButton.icon(
                      onPressed: _addEvidence,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _EvidenceSection(
                  evidence: _evidence,
                  onRemove: _removeEvidence,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Submit Incident'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incident type field + picker sheet
// ---------------------------------------------------------------------------

class _TypeSelectorField extends StatelessWidget {
  const _TypeSelectorField({required this.selectedType, required this.onTap});

  final IncidentType? selectedType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final type = selectedType;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: type == null ? AppColors.border : AppColors.accent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                type?.icon ?? Icons.report_outlined,
                color: type == null
                    ? AppColors.textSecondary
                    : AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type?.label ?? 'Select incident type',
                  style: textTheme.bodyLarge?.copyWith(
                    color: type == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentTypeSheet extends StatelessWidget {
  const _IncidentTypeSheet({required this.selectedType});

  final IncidentType? selectedType;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Incident Type', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final type in selectableIncidentTypes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TypeOptionTile(
                  type: type,
                  isSelected: type == selectedType,
                  onTap: () => Navigator.of(context).pop(type),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeOptionTile extends StatelessWidget {
  const _TypeOptionTile({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final IncidentType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: isSelected
          ? AppColors.accent.withOpacity(0.10)
          : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                type.icon,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(type.label, style: textTheme.bodyLarge)),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location section
// ---------------------------------------------------------------------------

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.state,
    required this.position,
    required this.onCapture,
  });

  final _LocationCaptureState state;
  final Position? position;
  final VoidCallback onCapture;

  String _formatCoordinate(
    double value, {
    required String positiveSuffix,
    required String negativeSuffix,
  }) {
    final suffix = value >= 0 ? positiveSuffix : negativeSuffix;
    return '${value.abs().toStringAsFixed(4)}° $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
          if (state == _LocationCaptureState.captured && position != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_formatCoordinate(position!.latitude, positiveSuffix: 'N', negativeSuffix: 'S')}\n'
                    '${_formatCoordinate(position!.longitude, positiveSuffix: 'E', negativeSuffix: 'W')}',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Update Location'),
            ),
          ] else if (state == _LocationCaptureState.unavailable) ...[
            Row(
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Location unavailable', style: textTheme.bodyLarge),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'You can still submit this report, but location evidence '
              'will not be attached.',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(
                  Icons.my_location_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add your current location as evidence for this report.',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state == _LocationCaptureState.capturing
                  ? null
                  : onCapture,
              icon: state == _LocationCaptureState.capturing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                state == _LocationCaptureState.capturing
                    ? 'Getting location…'
                    : 'Use Current Location',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Evidence section
// ---------------------------------------------------------------------------

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.evidence, required this.onRemove});

  final List<IncidentEvidenceItem> evidence;
  final ValueChanged<IncidentEvidenceItem> onRemove;

  String get _summaryLabel {
    if (evidence.isEmpty) return 'No evidence attached';
    if (evidence.length == 1) {
      return '1 ${evidence.first.type.label.toLowerCase()} attached';
    }
    return '${evidence.length} files attached';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
          Text(
            _summaryLabel,
            style: textTheme.bodyMedium?.copyWith(
              color: evidence.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in evidence) ...[
              _EvidenceRow(item: item, onRemove: () => onRemove(item)),
              if (item != evidence.last) const Divider(height: 20),
            ],
          ],
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.item, required this.onRemove});

  final IncidentEvidenceItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(item.type.icon, color: AppColors.accent, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(item.label, style: textTheme.bodyLarge)),
        Text(
          'Not uploaded',
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          color: AppColors.textSecondary,
          onPressed: onRemove,
          tooltip: 'Remove',
        ),
      ],
    );
  }
}

class _EvidenceTypeSheet extends StatelessWidget {
  const _EvidenceTypeSheet();

  static const _types = [
    EvidenceType.photo,
    EvidenceType.video,
    EvidenceType.document,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Evidence', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'This attaches a local placeholder for this session only — '
              'nothing is uploaded yet.',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),
            for (final type in _types)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(type),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            type.icon,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(type.label, style: textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}