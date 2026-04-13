import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';
import '../models/contact.dart' as app;
import '../providers/conversations_provider.dart';
import '../services/api_service.dart';
import '../widgets/avatar.dart';

class ContactInfoScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ContactInfoScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends ConsumerState<ContactInfoScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _tagController = TextEditingController();
  List<String> _tags = [];
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _saveContact() async {
    final convState = ref.read(conversationsProvider);
    final conversation = convState.conversations.where((c) => c.id == widget.conversationId).firstOrNull;
    if (conversation == null) return;

    setState(() => _saving = true);

    try {
      await ApiService().updateContact(conversation.contact.id, {
        'display_name': _nameController.text.trim(),
        'notes': _notesController.text.trim(),
        'company': _companyController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'tags': _tags,
      });
      // Refresh conversations to pick up name change
      ref.read(conversationsProvider.notifier).loadConversations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact updated'), backgroundColor: AppColors.accent),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update contact'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Widget _buildField(TextEditingController controller, String label, {int maxLines = 1, TextInputType? keyboardType, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
          prefixIcon: icon != null ? Icon(icon, color: ThemeProvider.instance.colors.textSecondary) : null,
          filled: true,
          fillColor: ThemeProvider.instance.colors.inputBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationsProvider);
    final conversation = convState.conversations.where((c) => c.id == widget.conversationId).firstOrNull;

    if (conversation == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Conversation not found', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary))),
      );
    }

    final contact = conversation.contact;

    if (!_initialized) {
      _nameController.text = contact.displayName ?? '';
      _notesController.text = contact.notes ?? '';
      _companyController.text = contact.company ?? '';
      _emailController.text = contact.email ?? '';
      _addressController.text = contact.address ?? '';
      _tags = List<String>.from(contact.tags ?? []);
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: ThemeProvider.instance.colors.background,
      appBar: AppBar(
        backgroundColor: ThemeProvider.instance.colors.headerBackground,
        title: const Text('Contact Info'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                )
              : IconButton(icon: const Icon(Icons.check), onPressed: _saveContact),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Avatar(
                name: contact.nameOrPhone,
                imageUrl: contact.profileImageUrl,
                radius: 56,
              ),
            ),
            const SizedBox(height: 24),
            _buildField(_nameController, 'Display Name', icon: Icons.person_outline),
            Center(
              child: Text(
                contact.phoneNumber,
                style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            _buildField(_companyController, 'Company', icon: Icons.business_outlined),
            _buildField(_emailController, 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            _buildField(_addressController, 'Address', icon: Icons.location_on_outlined, maxLines: 2),
            _buildField(_notesController, 'Notes', icon: Icons.note_outlined, maxLines: 3),

            // Tags
            Text('Tags', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _tags.map((tag) => Chip(
                label: Text(tag, style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 13)),
                backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                deleteIconColor: ThemeProvider.instance.colors.textSecondary,
                onDeleted: () => _removeTag(tag),
              )).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
                    onSubmitted: (_) => _addTag(),
                    decoration: InputDecoration(
                      hintText: 'Add tag (e.g. VIP, Customer)',
                      hintStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: ThemeProvider.instance.colors.inputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.accent),
                  onPressed: _addTag,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save to phone
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Save to Phone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _saveToPhone(contact),
              ),
            ),
            const SizedBox(height: 32),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive Chat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ThemeProvider.instance.colors.textSecondary,
                  side: BorderSide(color: ThemeProvider.instance.colors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final confirmed = await _confirmAction('Archive Chat', 'Are you sure you want to archive this chat?');
                  if (confirmed) {
                    await ref.read(conversationsProvider.notifier).archiveConversation(widget.conversationId);
                    if (context.mounted) context.go('/chats');
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Chat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final confirmed = await _confirmAction('Delete Chat', 'This action cannot be undone.');
                  if (confirmed && context.mounted) context.go('/chats');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToPhone(app.Contact contact) async {
    final status = await Permission.contacts.request();

    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact permission is required to save contacts'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enable contacts permission in Settings'),
            backgroundColor: AppColors.danger,
            action: SnackBarAction(
              label: 'Open Settings',
              textColor: ThemeProvider.instance.colors.textPrimary,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    try {
      final newContact = fc.Contact(
        name: fc.Name(first: contact.displayName ?? '', last: ''),
        phones: [fc.Phone(number: contact.phoneNumber)],
        emails: contact.email != null && contact.email!.isNotEmpty
            ? [fc.Email(address: contact.email!)]
            : [],
        organizations: contact.company != null && contact.company!.isNotEmpty
            ? [fc.Organization(name: contact.company!)]
            : [],
        addresses: contact.address != null && contact.address!.isNotEmpty
            ? [fc.Address(formatted: contact.address!)]
            : [],
        notes: contact.notes != null && contact.notes!.isNotEmpty
            ? [fc.Note(note: contact.notes!)]
            : [],
      );

      await fc.FlutterContacts.create(newContact);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contact.nameOrPhone} saved to phone'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save contact: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<bool> _confirmAction(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeProvider.instance.colors.surface,
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }
}
