import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/contact_message.dart';
import '../../services/contact_service.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/toast.dart';

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});
  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  List<ContactMessage> _messages = [];
  ({int total, int today, int lastWeek}) _stats =
      (total: 0, today: 0, lastWeek: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final l = await ContactService.instance.list();
      final s = await ContactService.instance.stats();
      if (!mounted) return;
      setState(() {
        _messages = l;
        _stats = s;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages = const [];
        _stats = (total: 0, today: 0, lastWeek: 0);
        _loading = false;
      });
    }
  }

  Future<void> _delete(int id) async {
    final ok = await confirmDialog(context,
        title: 'Delete message?', message: 'This cannot be undone.',
        confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    await ContactService.instance.delete(id);
    _load();
  }

  Future<void> _clearAll() async {
    final ok = await confirmDialog(context,
        title: 'Clear all messages?',
        message: 'This cannot be undone.',
        confirmLabel: 'Clear All',
        danger: true);
    if (!ok) return;
    await ContactService.instance.clearAll();
    _load();
  }

  Future<void> _openMail(String address) async {
    final uri = Uri(scheme: 'mailto', path: address);
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        Toast.show(context, 'No mail app available.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        Toast.show(context, 'Could not open mail app.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Contact Messages'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.danger),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Row(
                    children: [
                      _stat('Total', _stats.total),
                      const SizedBox(width: 10),
                      _stat('Today', _stats.today),
                      const SizedBox(width: 10),
                      _stat('7 Days', _stats.lastWeek),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_messages.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('No messages yet.',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    for (final m in _messages)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(m.name,
                                          style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w700)),
                                      GestureDetector(
                                        onTap: () => _openMail(m.email),
                                        child: Text(m.email,
                                            style: const TextStyle(
                                                color: AppColors.accent,
                                                fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  m.createdAt == null
                                      ? ''
                                      : Formatters.relativeDate(
                                          m.createdAt!),
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(m.message,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      height: 1.5)),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.delete_outline,
                                    size: 16, color: AppColors.danger),
                                label: const Text('Delete',
                                    style: TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 12)),
                                onPressed: () => _delete(m.messageId!),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text('$value',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}