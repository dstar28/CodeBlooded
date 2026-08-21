import 'package:flutter/material.dart';
import '../../models/emergency_contact.dart';
import '../../state/emergency_contacts_store.dart';
import '../../theme/app_colors.dart';

/// Add / Edit Emergency Contact form (Prompt #8).
///
/// Used for both flows: pass [existingContact] to edit it in place, or
/// omit it to add a brand-new contact. Saves only into the in-memory
/// [EmergencyContactsStore] — there is no Supabase persistence, OTP
/// verification, or real contact-reachability check here.
class ContactFormScreen extends StatefulWidget {
  const ContactFormScreen({super.key, this.existingContact});

  final EmergencyContact? existingContact;

  bool get isEditing => existingContact != null;

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _emailController;

  late bool _isPrimary;

  // Accepts normal international phone formats — digits, spaces, and an
  // optional leading +, with optional separators like - ( ). Tourists are
  // not assumed to have an Indian number, so no country code is enforced.
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9\s\-()]{7,20}$');
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    final existing = widget.existingContact;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _relationshipController = TextEditingController(
      text: existing?.relationship ?? '',
    );
    _emailController = TextEditingController(text: existing?.email ?? '');
    _isPrimary = existing?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Phone number is required';
    }
    if (!_phonePattern.hasMatch(trimmed)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validateRelationship(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Relationship is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null; // optional field
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final store = EmergencyContactsStore.instance;
    final existing = widget.existingContact;

    final contact = EmergencyContact(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      relationship: _relationshipController.text.trim(),
      email: _emailController.text.trim(),
      isPrimary: _isPrimary,
    );

    if (widget.isEditing) {
      store.updateContact(contact);
    } else {
      store.addContact(contact);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Contact' : 'Add Contact'),
      ),
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
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Priya Sharma',
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+91 98765 43210',
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _relationshipController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    hintText: 'Sister, Friend, Colleague…',
                  ),
                  validator: _validateRelationship,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    hintText: 'priya@example.com',
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                _PrimaryToggle(
                  value: _isPrimary,
                  onChanged: (value) => setState(() => _isPrimary = value),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Save Contact'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryToggle extends StatelessWidget {
  const _PrimaryToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.accent,
        title: Text('Set as primary contact', style: textTheme.bodyLarge),
        subtitle: Text(
          'This person is contacted first during an emergency.',
          style: textTheme.bodyMedium,
        ),
      ),
    );
  }
}
