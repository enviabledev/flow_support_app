import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/contact.dart';
import '../providers/conversations_provider.dart';
import '../services/api_service.dart';
import '../widgets/avatar.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchController = TextEditingController();
  final _phoneController = TextEditingController();
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final response = await ApiService().getContacts();
      final data = response.data;
      final List<dynamic> list = data is List ? data : (data['contacts'] ?? data['data'] ?? []);
      setState(() {
        _contacts = list.map((j) => Contact.fromJson(j as Map<String, dynamic>)).toList();
        _filtered = _contacts;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _contacts;
      } else {
        final q = query.toLowerCase();
        _filtered = _contacts.where((c) {
          return c.nameOrPhone.toLowerCase().contains(q) ||
              c.phoneNumber.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _openConversationForContact(Contact contact) async {
    // Check if conversation already exists in loaded list
    final convState = ref.read(conversationsProvider);
    final existing = convState.conversations.where(
      (c) => c.contact.id == contact.id,
    ).firstOrNull;

    if (existing != null) {
      if (mounted) context.go('/chats/${existing.id}');
      return;
    }

    // Create or find conversation via API
    try {
      final response = await ApiService().createConversation(contact.id);
      final data = response.data;
      final conv = data['conversation'] ?? data;
      final convId = conv['id']?.toString();
      if (convId != null && mounted) {
        // Refresh conversations list
        ref.read(conversationsProvider.notifier).loadConversations();
        context.go('/chats/$convId');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open conversation'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        title: const Text('New Chat'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search contacts',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.inputBackground,
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('+234', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter phone number',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, color: AppColors.accent),
                  onPressed: () {
                    final phone = _phoneController.text.trim();
                    if (phone.isEmpty) return;
                    final fullPhone = '+234$phone';
                    // Find contact by phone number
                    final match = _contacts.where((c) => c.phoneNumber == fullPhone || c.phoneNumber.endsWith(phone)).firstOrNull;
                    if (match != null) {
                      _openConversationForContact(match);
                    } else {
                      // Create a temporary contact object to trigger conversation creation
                      // The backend handleIncomingMessage creates contacts, but for outbound
                      // we need the contact to exist first. Show a message.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contact not found. Contacts are created when they message first.'),
                          backgroundColor: AppColors.headerBackground,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final contact = _filtered[index];
                      return ListTile(
                        leading: Avatar(name: contact.nameOrPhone, radius: 22),
                        title: Text(
                          contact.nameOrPhone,
                          style: AppTypography.contactName,
                        ),
                        subtitle: Text(
                          contact.phoneNumber,
                          style: AppTypography.lastMessage,
                        ),
                        onTap: () => _openConversationForContact(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
