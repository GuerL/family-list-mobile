import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../data/family_models.dart';
import 'family_detail_screen.dart';
import 'families_controller.dart';
import 'selected_family_provider.dart';

class FamiliesScreen extends ConsumerStatefulWidget {
  const FamiliesScreen({super.key});

  static const routePath = '/families';

  @override
  ConsumerState<FamiliesScreen> createState() => _FamiliesScreenState();
}

class _FamiliesScreenState extends ConsumerState<FamiliesScreen> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(familiesControllerProvider, (_, next) {
      next.whenData(_syncSelectedFamily);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.whenOrNull(data: (session) => session?.user);

    if (authState.isLoading || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final familiesState = ref.watch(familiesControllerProvider);
    final selectedFamily = ref.watch(selectedFamilyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Families'),
        actions: [
          _AccountMenu(
            name: user.fullName,
            email: user.email,
            onLogout: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateFamilySheet(),
        icon: const Icon(Icons.add),
        label: const Text('Create family'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _reloadFamilies(ref),
        child: AsyncValueView<List<FamilyDto>>(
          value: familiesState,
          onRetry: () => _reloadFamilies(ref),
          data: (families) {
            if (families.isEmpty) {
              return _FamiliesEmptyState(
                onCreateFamily: _showCreateFamilySheet,
                onJoinFamily: _showJoinFamilySheet,
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: families.length + 2,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FamiliesHeader(
                    userName: user.fullName,
                    familyCount: families.length,
                    onJoinFamily: _showJoinFamilySheet,
                  );
                }

                if (index == 1) {
                  return const SizedBox(height: 2);
                }

                final family = families[index - 2];
                final isSelected = selectedFamily?.id == family.id;
                return _FamilyCard(
                  family: family,
                  isSelected: isSelected,
                  onTap: () {
                    ref.read(selectedFamilyProvider.notifier).select(family);
                    final familyId = family.id;
                    if (familyId != null) {
                      context.push(FamilyDetailScreen.routePath(familyId));
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _syncSelectedFamily(List<FamilyDto> families) {
    final selectedFamily = ref.read(selectedFamilyProvider);
    if (families.isEmpty) {
      ref.read(selectedFamilyProvider.notifier).select(null);
      return;
    }

    if (selectedFamily != null &&
        families.any((family) => family.id == selectedFamily.id)) {
      return;
    }

    ref
        .read(selectedFamilyProvider.notifier)
        .select(families.length == 1 ? families.first : null);
  }

  Future<void> _reloadFamilies(WidgetRef ref) async {
    ref.invalidate(familiesControllerProvider);
    await ref.read(familiesControllerProvider.future);
  }

  Future<void> _showCreateFamilySheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FamilyFormSheet(
        title: 'Create family',
        initialName: '',
        initialDescription: '',
        initialImageUrl: null,
        submitLabel: 'Create',
        onSubmit: (name, description, imageUrl) async {
          await ref
              .read(familyManagementControllerProvider)
              .create(name: name, description: description, imageUrl: imageUrl);
        },
      ),
    );

    if (created == true && mounted) {
      await _reloadFamilies(ref);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Family created.')));
      }
    }
  }

  Future<void> _showJoinFamilySheet() async {
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _JoinFamilySheet(
        onSubmit: (inviteCode) async {
          await ref.read(familyManagementControllerProvider).join(inviteCode);
        },
      ),
    );

    if (joined == true && mounted) {
      await _reloadFamilies(ref);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Family joined.')));
      }
    }
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({
    required this.name,
    required this.email,
    required this.onLogout,
  });

  final String? name;
  final String email;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final displayName = name == null || name!.trim().isEmpty
        ? email
        : name!.trim();

    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      onSelected: (action) {
        switch (action) {
          case _AccountAction.logout:
            onLogout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(_initialsFor(displayName))),
            title: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountAction.logout,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Logout'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: CircleAvatar(child: Text(_initialsFor(displayName))),
      ),
    );
  }
}

enum _AccountAction { logout }

class _FamiliesHeader extends StatelessWidget {
  const _FamiliesHeader({
    required this.userName,
    required this.familyCount,
    required this.onJoinFamily,
  });

  final String? userName;
  final int familyCount;
  final VoidCallback onJoinFamily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = userName?.trim();
    final greeting = displayName == null || displayName.isEmpty
        ? 'Welcome back'
        : 'Welcome back, $displayName';
    final familyLabel = familyCount == 1 ? '1 family' : '$familyCount families';

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '$familyLabel ready for lists, products, and shopping context.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onJoinFamily,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Join family'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamiliesEmptyState extends StatelessWidget {
  const _FamiliesEmptyState({
    required this.onCreateFamily,
    required this.onJoinFamily,
  });

  final VoidCallback onCreateFamily;
  final VoidCallback onJoinFamily;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 24),
      children: [
        EmptyState(
          title: 'No families yet',
          message:
              'Create or join a family to start organizing lists together.',
          action: FilledButton.icon(
            onPressed: onCreateFamily,
            icon: const Icon(Icons.add),
            label: const Text('Create family'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: onJoinFamily,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Join family'),
          ),
        ),
      ],
    );
  }
}

class _JoinFamilySheet extends StatefulWidget {
  const _JoinFamilySheet({required this.onSubmit});

  final Future<void> Function(String inviteCode) onSubmit;

  @override
  State<_JoinFamilySheet> createState() => _JoinFamilySheetState();
}

class _JoinFamilySheetState extends State<_JoinFamilySheet> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Join family', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Enter the invite code shared by a family member.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _inviteCodeController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Invite code'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Invite code is required.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join family'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(_inviteCodeController.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = ApiError.fromObject(error).message;
        _isSubmitting = false;
      });
    }
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.family,
    required this.isSelected,
    required this.onTap,
  });

  final FamilyDto family;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberCount = family.members.length;
    final memberLabel = memberCount == 1 ? '1 member' : '$memberCount members';
    final description = family.description.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FamilyBanner(family: family),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          family.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        _SelectedBadge(color: theme.colorScheme.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(icon: Icons.people_outline, label: memberLabel),
                      if (family.isActive == false)
                        const _MetaChip(
                          icon: Icons.pause_circle_outline,
                          label: 'Inactive',
                        ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyBanner extends StatelessWidget {
  const _FamilyBanner({required this.family});

  final FamilyDto family;

  @override
  Widget build(BuildContext context) {
    final imageUrl = family.imageUrl?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 7,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _FallbackBanner(familyName: family.name);
          },
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 7,
      child: _FallbackBanner(familyName: family.name),
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner({required this.familyName});

  final String familyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(
                  _initialsFor(familyName),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
          ),
          Positioned(
            right: -28,
            bottom: -34,
            child: Icon(
              Icons.family_restroom,
              size: 132,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.check_circle, color: color, size: 24);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _initialsFor(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.characters.first.toUpperCase();
}
