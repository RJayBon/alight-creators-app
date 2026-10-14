import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/tutorial.dart';
import '../../services/tutorial_service.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/section_title.dart';
import '../../widgets/tutorial_card.dart';

class TutorialsTab extends StatefulWidget {
  const TutorialsTab({super.key, required this.onOpenTutorial});
  final void Function(Tutorial) onOpenTutorial;

  @override
  State<TutorialsTab> createState() => _TutorialsTabState();
}

class _TutorialsTabState extends State<TutorialsTab> {
  String _selected = 'All';
  final _searchCtrl = TextEditingController();
  List<Tutorial> _items = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = TutorialService.instance;
      final list = _query.isNotEmpty
          ? await s.search(_query)
          : await s.listByCategory(_selected);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _error = 'Could not load tutorials. Pull down to retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                  _query.isNotEmpty ? 'Search Results' : _headerFor(_selected),
                  accent: true),
              const SizedBox(height: 8),
              Text(_descFor(_selected),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 14),
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textSecondary),
                  hintText: 'Search tutorials…',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
                onSubmitted: (v) {
                  setState(() => _query = v.trim());
                  _load();
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = kCategories[i];
                    final active = c == _selected && _query.isEmpty;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selected = c;
                          _query = '';
                          _searchCtrl.clear();
                        });
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              active ? AppColors.accent : AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: active
                                  ? AppColors.accent
                                  : AppColors.border),
                        ),
                        child: Text(kCategoryLabels[c] ?? c,
                            style: TextStyle(
                                color: active
                                    ? AppColors.background
                                    : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ErrorBanner(message: _error!),
                        ),
                      if (_items.isEmpty && _error == null)
                        EmptyState(
                          icon: Icons.search_off,
                          title: _query.isNotEmpty
                              ? 'No tutorials found for "$_query".'
                              : 'No tutorials in this category yet.',
                          subtitle: _query.isNotEmpty
                              ? 'Try a different keyword, or clear the search.'
                              : null,
                        )
                      else if (_items.isNotEmpty)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 12.0;
                            final cellW =
                                (constraints.maxWidth - gap) / 2;
                            final cellH = cellW * 9 / 16 + 130;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: cellH,
                                crossAxisSpacing: gap,
                                mainAxisSpacing: gap,
                              ),
                              itemBuilder: (context, i) => TutorialCard(
                                tutorial: _items[i],
                                onTap: () =>
                                    widget.onOpenTutorial(_items[i]),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  String _headerFor(String c) {
    switch (c) {
      case 'Beginner':      return 'Beginner Tutorials';
      case 'Intermediate':  return 'Intermediate Tutorials';
      case 'Advanced':      return 'Advanced Tutorials';
      case 'Tips & Tricks': return 'Tips & Tricks';
      default:              return 'All Tutorials';
    }
  }

  String _descFor(String c) {
    switch (c) {
      case 'Beginner':
        return 'Start your journey with these fundamental guides.';
      case 'Intermediate':
        return 'Level up with more complex techniques.';
      case 'Advanced':
        return 'Master Alight Motion with pro workflows.';
      case 'Tips & Tricks':
        return 'Quick hacks, shortcuts, and advice.';
      default:
        return 'Browse our entire library of motion design guides.';
    }
  }
}