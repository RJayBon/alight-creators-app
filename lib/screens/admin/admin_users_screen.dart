import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../theme.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/public_profile_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  List<AppUser> _users = [];
  Map<int, int> _counts = {};
  int _total = 0;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  Timer? _debounce;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _page = 1;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await UserService.instance.paginated(
        page: _page,
        perPage: _pageSize,
        search: _search.text.trim(),
      );
      final ids = r.users.map((u) => u.userId!).toList();
      final counts = await UserService.instance.tutorialCounts(ids);
      if (!mounted) return;
      setState(() {
        _users = r.users;
        _total = r.total;
        _totalPages = r.totalPages;
        _counts = counts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _users = const [];
        _total = 0;
        _totalPages = 1;
        _counts = const {};
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Manage Users'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textSecondary),
                      hintText: 'Search by name, @handle, or email…',
                      hintStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$_total users',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _users.length,
                      itemBuilder: (context, i) {
                        final u = _users[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.border,
                                child: Text(u.initials,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(u.displayName,
                                            style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700)),
                                        if (u.isAdmin)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 6),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.border,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text('ADMIN',
                                                style: TextStyle(
                                                    color: AppColors.accent,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                      ],
                                    ),
                                    Text('@${u.username}',
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11)),
                                    Text(u.email,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${_counts[u.userId] ?? 0}',
                                      style: const TextStyle(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700)),
                                  const Text('tutorials',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 10)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility,
                                            size: 18,
                                            color: AppColors.textSecondary),
                                        onPressed: () =>
                                            Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                PublicProfileScreen(
                                                    username: u.username),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            size: 18,
                                            color: AppColors.accent),
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  EditProfileScreen(
                                                      targetUserId: u.userId),
                                            ),
                                          );
                                          if (mounted) _load();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_totalPages > 1)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _page > 1
                          ? () {
                              _page--;
                              _load();
                            }
                          : null,
                      child: const Text('← Prev'),
                    ),
                    Text('Page $_page of $_totalPages',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    TextButton(
                      onPressed: _page < _totalPages
                          ? () {
                              _page++;
                              _load();
                            }
                          : null,
                      child: const Text('Next →'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}