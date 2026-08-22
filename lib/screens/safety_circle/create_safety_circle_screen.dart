import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../../state/safety_circle_store.dart';
import '../../state/trip_store.dart';
import '../../theme/app_colors.dart';

/// Create Safety Circle form (Prompt #9).
///
/// On submit this only writes into the in-memory [SafetyCircleStore] and
/// generates a mock group code locally — there is no real backend group
/// service or Supabase Realtime sync yet.
class CreateSafetyCircleScreen extends StatefulWidget {
  const CreateSafetyCircleScreen({super.key});

  @override
  State<CreateSafetyCircleScreen> createState() =>
      _CreateSafetyCircleScreenState();
}

class _CreateSafetyCircleScreenState extends State<CreateSafetyCircleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Trip? _selectedTrip;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || _submitting) return;

    setState(() => _submitting = true);

    final result = await SafetyCircleStore.instance.createGroup(
      name: _nameController.text.trim(),
      tripName: _selectedTrip?.name,
    );

    if (!mounted) return;

    if (!result.success || result.group == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ??
                'Could not create the Safety Circle. Please try again.',
          ),
        ),
      );
      return;
    }

    final createdGroup = result.group!;
    setState(() => _submitting = false);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Safety Circle Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Group Code:'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withOpacity(0.35)),
              ),
              child: Text(
                createdGroup.code,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Share this code with your travel companions.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final trips = TripStore.instance.trips;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Safety Circle')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'Goa Trip',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Group name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (trips.isNotEmpty) ...[
                  DropdownButtonFormField<Trip>(
                    value: _selectedTrip,
                    decoration: const InputDecoration(
                      labelText: 'Trip (optional)',
                      hintText: 'Link this circle to a trip',
                    ),
                    items: trips
                        .map(
                          (trip) => DropdownMenuItem<Trip>(
                            value: trip,
                            child: Text(trip.name),
                          ),
                        )
                        .toList(),
                    onChanged: (trip) => setState(() => _selectedTrip = trip),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Circle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
