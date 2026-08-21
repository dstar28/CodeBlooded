import 'package:flutter/material.dart';
import '../../models/trip.dart';
import '../../state/trip_store.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';

/// Create Trip form.
///
/// On successful submit this only writes into the in-memory [TripStore] —
/// there is no Supabase persistence yet. Fields match Prompt #5 exactly:
/// Trip Name, Destination, Start Date, End Date, and optional Notes.
class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _dateError;

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;

    setState(() {
      _startDate = picked;
      // If the end date is now before the new start date, clear it so the
      // user is prompted to pick a valid one rather than silently keeping
      // an invalid range.
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = null;
      }
      _dateError = null;
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final firstAllowed = _startDate ?? DateTime(now.year - 1);
    final initial = _endDate ?? _startDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstAllowed) ? firstAllowed : initial,
      firstDate: firstAllowed,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;

    setState(() {
      _endDate = picked;
      _dateError = null;
    });
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() ?? false;

    String? dateError;
    if (_startDate == null || _endDate == null) {
      dateError = 'Start and end dates are required';
    } else if (_endDate!.isBefore(_startDate!)) {
      dateError = 'End date cannot be before start date';
    }

    setState(() => _dateError = dateError);

    if (!formValid || dateError != null) return;

    final trip = Trip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      destination: _destinationController.text.trim(),
      startDate: _startDate!,
      endDate: _endDate!,
      status: TripStatus.upcoming,
      notes: _notesController.text.trim(),
    );

    TripStore.instance.addTrip(trip);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan a Trip')),
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Trip Name',
                    hintText: 'Weekend trip to Goa',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Trip name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _destinationController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    hintText: 'Goa',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Destination is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _DateField(
                  label: 'Start Date',
                  value: _startDate,
                  onTap: _pickStartDate,
                ),
                const SizedBox(height: 16),
                _DateField(
                  label: 'End Date',
                  value: _endDate,
                  onTap: _pickEndDate,
                ),
                if (_dateError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _dateError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Anything you want to remember about this trip',
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Create Trip'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value != null ? formatFullDate(value!) : 'Select date',
                      style: TextStyle(
                        color: value != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.accent,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}