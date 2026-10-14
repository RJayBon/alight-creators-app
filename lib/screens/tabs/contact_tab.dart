import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import '../../services/rate_limit_service.dart';
import '../../theme.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/section_title.dart';
import '../../widgets/toast.dart';

class ContactTab extends StatefulWidget {
  const ContactTab({super.key});
  @override
  State<ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<ContactTab> {
  final _msg = TextEditingController();
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _name.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _msg.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    if (_msg.text.trim().isEmpty) {
      setState(() => _error = 'Please write a message.');
      return;
    }
    if (_msg.text.length > 5000) {
      setState(() => _error = 'Message is too long (max 5000).');
      return;
    }
    if (!RateLimitService.instance.allow('contact', max: 3, windowSec: 600)) {
      setState(() => _error = "You're sending messages too fast. Please wait.");
      return;
    }
    setState(() => _busy = true);
    try {
      await ContactService.instance.insert(
        name: user.displayName,
        email: user.email,
        message: _msg.text.trim(),
      );
      if (!mounted) return;
      _msg.clear();
      Toast.show(context, "Message sent! We'll get back to you soon.");
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not send: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 28 + MediaQuery.of(context).viewInsets.bottom),
        children: [
          const Center(child: SectionTitle('Get in Touch')),
          const SizedBox(height: 10),
          const Text(
              'Have a question or want to request a specific tutorial?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                LabeledField(
                  label: 'Name',
                  hintText: user?.displayName ?? 'Your Name',
                  controller: _name,
                  readOnly: true,
                ),
                const SizedBox(height: 8),
                Text('Replies will be sent to ${user?.email ?? ''}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 18),
                LabeledField(
                  label: 'Message',
                  hintText: 'How can we help?',
                  controller: _msg,
                  maxLines: 5,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                PillButton(
                    label: 'Send Message', onPressed: _send, loading: _busy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}