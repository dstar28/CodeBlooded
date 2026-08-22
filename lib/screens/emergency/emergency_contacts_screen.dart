import 'package:flutter/material.dart';
import '../../models/emergency_contact.dart';
import '../../state/emergency_contacts_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sync_status_badge.dart';
import 'contact_form_screen.dart';

/// Emergency Contacts screen (Prompt #8).
///
/// Lets a traveler add, edit, delete, and mark a primary trusted contact.
/// [EmergencyContactsStore] remains the source of truth for the current
/// app session; as of Prompt #12 it also persists changes to Supabase in
/// the background. This screen shows the resulting sync status in the
/// app bar — there is still no real SMS/calls or notifications behind
/// this screen.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  @override
  void initState() {
    super.initState();
    EmergencyContactsStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    EmergencyContactsStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _openAddContact() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContactFormScreen()),
    );
  }

  void _openEditContact(EmergencyContact contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactFormScreen(existingContact: contact),
      ),
    );
  }

  Future<void> _confirmDelete(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Contact?'),
        content: const Text(
          'Are you sure you want to remove this emergency contact?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      EmergencyContactsStore.instance.deleteContact(contact.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = EmergencyContactsStore.instance.contacts;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: SyncStatusBadge(
                state: EmergencyContactsStore.instance.syncState,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'People you trust can be notified when you need help.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (contacts.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: _openAddContact,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add Contact'),
                ),
                const SizedBox(height: 20),
              ],
              if (contacts.isEmpty)
                _EmptyState(onAddContact: _openAddContact)
              else
                Column(
                  children: [
                    for (final contact in contacts) ...[
                      _ContactCard(
                        contact: contact,
                        onEdit: () => _openEditContact(contact),
                        onDelete: () => _confirmDelete(contact),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddContact});

  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.contact_phone_outlined,
              color: AppColors.accent,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text('No emergency contacts yet', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Add someone you trust so they can be reached when you need '
            'help.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAddContact,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Add Emergency Contact'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact card
// ---------------------------------------------------------------------------

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            style: textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (contact.isPrimary) ...[
                          const SizedBox(width: 8),
                          const _PrimaryBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(contact.relationship, style: textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      contact.phone,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surface,
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
      ),
      child: const Text(
        'PRIMARY',
        style: TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}