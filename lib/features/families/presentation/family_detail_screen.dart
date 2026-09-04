import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../data/family_models.dart';
import 'families_controller.dart';
import 'families_screen.dart';

class FamilyDetailScreen extends ConsumerWidget {
  const FamilyDetailScreen({super.key, required this.familyId});

  final int familyId;

  static String routePath(int familyId) => '/families/$familyId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyDetailProvider(familyId));
    final userEmail = ref
        .watch(authControllerProvider)
        .whenOrNull(data: (session) => session?.user.email);

    return Scaffold(
      body: AsyncValueView<FamilyDto>(
        value: familyState,
        onRetry: () async {
          ref.invalidate(familyDetailProvider(familyId));
          await ref.read(familyDetailProvider(familyId).future);
        },
        data: (family) => _FamilyDetailContent(
          family: family,
          currentUserEmail: userEmail,
          onEdit: () => _showEditFamilySheet(context, ref, family),
          onDelete: () => _confirmDeleteFamily(context, ref, family),
        ),
      ),
    );
  }

  Future<void> _showEditFamilySheet(
    BuildContext context,
    WidgetRef ref,
    FamilyDto family,
  ) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FamilyFormSheet(
        title: 'Edit family',
        initialName: family.name,
        initialDescription: family.description,
        initialImageUrl: family.imageUrl,
        submitLabel: 'Save',
        onSubmit: (name, description, imageUrl) async {
          await ref
              .read(familyManagementControllerProvider)
              .update(
                FamilyDto(
                  id: family.id,
                  name: name,
                  description: description,
                  members: family.members,
                  creator: family.creator,
                  imageUrl: imageUrl,
                  inviteCode: family.inviteCode,
                  isActive: family.isActive,
                ),
              );
        },
      ),
    );

    if (updated == true) {
      ref.invalidate(familyDetailProvider(familyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Family updated.')));
      }
    }
  }

  Future<void> _confirmDeleteFamily(
    BuildContext context,
    WidgetRef ref,
    FamilyDto family,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${family.name}"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await ref.read(familyManagementControllerProvider).delete(family);
      if (context.mounted) {
        context.go(FamiliesScreen.routePath);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Family deleted.')));
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final apiError = ApiError.fromObject(error);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiError.message)));
    }
  }
}

class _FamilyDetailContent extends StatelessWidget {
  const _FamilyDetailContent({
    required this.family,
    required this.currentUserEmail,
    required this.onEdit,
    required this.onDelete,
  });

  final FamilyDto family;
  final String? currentUserEmail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberCount = family.members.length;
    final memberLabel = memberCount == 1 ? '1 member' : '$memberCount members';
    final inviteCode = family.inviteCode?.trim();
    final canAttemptOwnerActions =
        currentUserEmail != null && family.creator?.email == currentUserEmail;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(
            family.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            PopupMenuButton<_FamilyDetailAction>(
              tooltip: 'Family actions',
              onSelected: (action) {
                switch (action) {
                  case _FamilyDetailAction.edit:
                    onEdit();
                  case _FamilyDetailAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _FamilyDetailAction.edit,
                  enabled: canAttemptOwnerActions,
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit family'),
                  ),
                ),
                PopupMenuItem(
                  value: _FamilyDetailAction.delete,
                  enabled: canAttemptOwnerActions,
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete family'),
                  ),
                ),
              ],
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FamilyHero(family: family),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(family.name, style: theme.textTheme.headlineSmall),
                    if (family.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        family.description.trim(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          icon: Icons.people_outline,
                          label: memberLabel,
                        ),
                        if (family.isActive == false)
                          const _MetaChip(
                            icon: Icons.pause_circle_outline,
                            label: 'Inactive',
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _InviteSection(inviteCode: inviteCode),
                    const SizedBox(height: 24),
                    Text('Members', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (family.members.isEmpty)
                      const EmptyState(
                        title: 'No members',
                        message: 'Members will appear here after they join.',
                      )
                    else
                      _MembersList(
                        members: family.members,
                        creatorEmail: family.creator?.email,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _FamilyDetailAction { edit, delete }

class _FamilyHero extends StatelessWidget {
  const _FamilyHero({required this.family});

  final FamilyDto family;

  @override
  Widget build(BuildContext context) {
    final imageUrl = family.imageUrl?.trim();

    return AspectRatio(
      aspectRatio: 16 / 8,
      child: imageUrl == null || imageUrl.isEmpty
          ? _FallbackBanner(familyName: family.name)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _FallbackBanner(familyName: family.name);
              },
            ),
    );
  }
}

class _InviteSection extends StatelessWidget {
  const _InviteSection({required this.inviteCode});

  final String? inviteCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite code', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (inviteCode == null || inviteCode!.isEmpty)
              Text(
                'No invite code available.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              SelectableText(
                inviteCode!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => _copyInviteCode(context, inviteCode!),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share will be added later.'),
                      ),
                    ),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copyInviteCode(BuildContext context, String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invite code copied.')));
    }
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.members, required this.creatorEmail});

  final List<FamilyUserDto> members;
  final String? creatorEmail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final member in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(_initialsFor(member.label))),
            title: Text(member.label),
            subtitle: member.email == null ? null : Text(member.email!),
            trailing: member.email == creatorEmail
                ? const Chip(label: Text('Owner'))
                : null,
          ),
      ],
    );
  }
}

class FamilyFormSheet extends StatefulWidget {
  const FamilyFormSheet({
    super.key,
    required this.title,
    required this.initialName,
    required this.initialDescription,
    required this.initialImageUrl,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final String initialName;
  final String initialDescription;
  final String? initialImageUrl;
  final String submitLabel;
  final Future<void> Function(String name, String description, String? imageUrl)
  onSubmit;

  @override
  State<FamilyFormSheet> createState() => _FamilyFormSheetState();
}

typedef _FamilyFormSheet = FamilyFormSheet;

class _FamilyFormSheetState extends State<FamilyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _imageUrlController = TextEditingController(
      text: widget.initialImageUrl ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
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
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Family name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Family description is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'Optional',
                ),
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
                    : Text(widget.submitLabel),
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

    final imageUrl = _imageUrlController.text.trim();

    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _descriptionController.text.trim(),
        imageUrl.isEmpty ? null : imageUrl,
      );
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

String _initialsFor(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.characters.first.toUpperCase();
}

extension on FamilyUserDto {
  String get label {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return email ?? 'Family member';
  }
}
