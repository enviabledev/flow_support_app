import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final response = await ApiService().getStaff();
      final data = response.data;
      final List<dynamic> list = data is List ? data : (data['staff'] ?? data['data'] ?? []);
      setState(() {
        _staff = list.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(String staffId, bool active) async {
    try {
      await ApiService().updateStaff(staffId, {'is_active': active});
      _loadStaff();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update staff'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    final nameController = TextEditingController(text: staff['name']);
    final emailController = TextEditingController(text: staff['email']);
    final passwordController = TextEditingController();
    String selectedRole = staff['role'] ?? 'agent';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ThemeProvider.instance.colors.surface,
          title: Text('Edit Staff', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                    filled: true,
                    fillColor: ThemeProvider.instance.colors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                    filled: true,
                    fillColor: ThemeProvider.instance.colors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'New Password (leave blank to keep)',
                    labelStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                    filled: true,
                    fillColor: ThemeProvider.instance.colors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  dropdownColor: ThemeProvider.instance.colors.surface,
                  style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                    filled: true,
                    fillColor: ThemeProvider.instance.colors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'agent', child: Text('Agent')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v ?? 'agent'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () async {
                try {
                  await ApiService().updateStaff(staff['id'].toString(), {
                    'name': nameController.text,
                    'email': emailController.text,
                    'role': selectedRole,
                  });
                  if (passwordController.text.isNotEmpty) {
                    await ApiService().resetStaffPassword(
                      staff['id'].toString(),
                      passwordController.text,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadStaff();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Staff updated'), backgroundColor: AppColors.accent),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStaffDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'agent';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ThemeProvider.instance.colors.surface,
          title: Text('Add Staff', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                    filled: true,
                    fillColor: ThemeProvider.instance.colors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                    filled: true,
                    fillColor: ThemeProvider.instance.colors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                    filled: true,
                    fillColor: ThemeProvider.instance.colors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  dropdownColor: ThemeProvider.instance.colors.surface,
                  style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                    filled: true,
                    fillColor: ThemeProvider.instance.colors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'agent', child: Text('Agent')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'agent'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text;
                if (name.isEmpty || email.isEmpty || password.isEmpty) return;
                try {
                  await ApiService().createStaff({
                    'name': name,
                    'email': email,
                    'password': password,
                    'role': role,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadStaff();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Staff member added'), backgroundColor: AppColors.accent),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null || !user.isAdmin) {
      return Scaffold(
        backgroundColor: ThemeProvider.instance.colors.background,
        appBar: AppBar(backgroundColor: ThemeProvider.instance.colors.headerBackground, title: Text('Access Denied')),
        body: Center(child: Text('Admin access required', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: ThemeProvider.instance.colors.background,
      appBar: AppBar(
        backgroundColor: ThemeProvider.instance.colors.headerBackground,
        title: Text('Staff Management', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: _showAddStaffDialog,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _loadStaff,
              child: _staff.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 200),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.people_outline, size: 64, color: ThemeProvider.instance.colors.textSecondary),
                              const SizedBox(height: 16),
                              Text('No staff members yet', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _staff.length,
                      itemBuilder: (context, index) {
                        final member = _staff[index];
                        final isActive = member['is_active'] ?? true;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive ? AppColors.accent : ThemeProvider.instance.colors.textSecondary,
                            child: Text(
                              (member['name'] ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                          title: Text(
                            member['name'] ?? '',
                            style: TextStyle(
                              color: isActive ? ThemeProvider.instance.colors.textPrimary : ThemeProvider.instance.colors.textSecondary,
                              fontWeight: FontWeight.w500,
                              decoration: isActive ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member['email'] ?? '',
                                style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: member['role'] == 'admin'
                                      ? AppColors.accent.withValues(alpha: 0.15)
                                      : ThemeProvider.instance.colors.inputBackground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  (member['role'] ?? 'agent').toString().toUpperCase(),
                                  style: TextStyle(
                                    color: member['role'] == 'admin' ? AppColors.accent : ThemeProvider.instance.colors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Switch(
                            value: isActive,
                            activeColor: AppColors.accent,
                            onChanged: (value) => _toggleActive(member['id'].toString(), value),
                          ),
                          onTap: () => _showEditStaffDialog(member),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
    );
  }
}
