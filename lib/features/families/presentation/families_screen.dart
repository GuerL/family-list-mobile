import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../data/family_models.dart';
import 'families_controller.dart';

class FamiliesScreen extends ConsumerWidget {
  const FamiliesScreen({super.key});

  static const routePath = '/families';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.whenOrNull(data: (session) => session?.user);

    if (authState.isLoading || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final familiesState = ref.watch(familiesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyList'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familiesControllerProvider);
          await ref.read(familiesControllerProvider.future);
        },
        child: AsyncValueView<List<FamilyDto>>(
          value: familiesState,
          onRetry: () async {
            ref.invalidate(familiesControllerProvider);
            await ref.read(familiesControllerProvider.future);
          },
          data: (families) {
            if (families.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No families yet.')),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: families.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SignedInHeader(
                    name: user.fullName,
                    email: user.email,
                  );
                }

                final family = families[index - 1];
                return _FamilyTile(family: family);
              },
            );
          },
        ),
      ),
    );
  }
}

class _SignedInHeader extends StatelessWidget {
  const _SignedInHeader({required this.name, required this.email});

  final String? name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null || name!.isEmpty ? email : name!,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyTile extends StatelessWidget {
  const _FamilyTile({required this.family});

  final FamilyDto family;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberCount = family.members.length;

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(_initialsFor(family.name))),
        title: Text(family.name),
        subtitle: Text(
          family.description.isEmpty
              ? '$memberCount member${memberCount == 1 ? '' : 's'}'
              : family.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: family.isActive == false
            ? Icon(
                Icons.pause_circle_outline,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }

  String _initialsFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.characters.first.toUpperCase();
  }
}
