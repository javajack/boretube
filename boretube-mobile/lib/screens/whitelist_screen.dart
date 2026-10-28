import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/whitelist_entry.dart';
import '../providers/providers.dart';
import '../ui/components.dart';
import '../ui/controls.dart';
import '../ui/tokens.dart';

const kBackdropId = 'E8C28D3C';

/// Asks the TV what's on and offers to allow it in Lock for a while.
Future<void> allowWhatsPlaying(BuildContext context, WidgetRef ref) async {
  final tvService = ref.read(tvServiceProvider);
  final status = await tvService?.getStatus();
  if (!context.mounted) return;
  if (status == null) {
    showStatusSnack(
      context,
      'The TV didn\'t answer. Is it on and on this Wi-Fi?',
      ok: false,
    );
    return;
  }
  final allowed =
      ref.read(whitelistProvider).any((e) => e.appId == status.appId);
  await showBtSheet<void>(
    context,
    builder: (sheet) {
      final (title, line, tone) = status.isIdle
          ? (
              'The home screen',
              'Nothing is playing. The home screen is always allowed.',
              Tone.idle,
            )
          : allowed
              ? (
                  status.appName,
                  'Already allowed. It keeps playing during the lock.',
                  Tone.ok,
                )
              : (
                  status.appName,
                  'Not allowed yet: the lock would stop it.',
                  Tone.warn,
                );
      return SheetScaffold(
        key: const Key('whats-playing'),
        title: 'On the TV now',
        children: [
          RowList(
            edges: true,
            children: [
              StatusRow(
                tone: tone,
                icon: status.isIdle ? Icons.home_rounded : Icons.live_tv,
                title: title,
                detail: line,
                detailLines: 2,
              ),
            ],
          ),
          const SizedBox(height: Gap.related),
          if (!status.isIdle && !allowed)
            PrimaryButton(
              key: const Key('whats-playing-allow'),
              label: 'Allow ${status.appName}',
              icon: Icons.check_rounded,
              kind: ButtonKind.ink,
              onPressed: () async {
                await ref.read(whitelistProvider.notifier).add(
                      WhitelistEntry(
                        appId: status.appId,
                        friendlyName: status.appName,
                      ),
                    );
                if (sheet.mounted) Navigator.pop(sheet);
                if (context.mounted) {
                  showStatusSnack(context, '${status.appName} allowed');
                }
              },
            )
          else
            PrimaryButton(
              label: 'Done',
              kind: ButtonKind.outline,
              onPressed: () => Navigator.pop(sheet),
            ),
        ],
      );
    },
  );
}

/// Adds an app by its Cast app ID (for apps that aren't on right now).
Future<void> addWhitelistById(BuildContext context, WidgetRef ref) async {
  final entry = await showBtSheet<WhitelistEntry>(
    context,
    builder: (_) => const _AddByIdSheet(),
  );
  if (entry != null) await ref.read(whitelistProvider.notifier).add(entry);
}

class _AddByIdSheet extends StatefulWidget {
  const _AddByIdSheet();

  @override
  State<_AddByIdSheet> createState() => _AddByIdSheetState();
}

class _AddByIdSheetState extends State<_AddByIdSheet> {
  final _id = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetScaffold(
        title: 'Allow an app by its ID',
        lead: const Text(
          'Easier: play the app on the TV and use "What\'s playing". Use '
          'this when you know its Cast app ID.',
        ),
        children: [
          TextField(
            key: const Key('whitelist-id'),
            controller: _id,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'App ID',
              hintText: 'e.g. 233637DE',
            ),
          ),
          const SizedBox(height: Gap.f13),
          TextField(
            key: const Key('whitelist-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. YouTube',
            ),
          ),
          const SizedBox(height: Gap.f13),
          ListenableBuilder(
            listenable: _id,
            builder: (context, _) => PrimaryButton(
              key: const Key('whitelist-add'),
              label: 'Allow',
              kind: ButtonKind.ink,
              onPressed: _id.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                        context,
                        WhitelistEntry(
                          appId: _id.text.trim(),
                          friendlyName: _name.text.trim().isEmpty
                              ? 'Unknown app'
                              : _name.text.trim(),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The allowed apps of Lock for a while, as rows (the full page).
class WhitelistScreen extends ConsumerWidget {
  const WhitelistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whitelist = ref.watch(whitelistProvider);
    final bt = context.bt;
    return DetailPage(
      title: 'Allowed apps',
      subtitle: 'Anything else stops during Lock for a while.',
      children: [
        RowList(
          edges: true,
          children: [
            ListRow(
              key: const Key('whitelist-whats-playing'),
              icon: Icons.live_tv_rounded,
              title: 'What\'s playing?',
              subtitle: 'Allow the app that\'s on the TV now',
              onTap: () => allowWhatsPlaying(context, ref),
            ),
            ListRow(
              key: const Key('whitelist-add-by-id'),
              icon: Icons.add_rounded,
              title: 'Add by ID',
              subtitle: 'For an app that isn\'t on right now',
              onTap: () => addWhitelistById(context, ref),
            ),
          ],
        ),
        GroupHeading(
          'Allowed',
          trailing: Text(
            '${whitelist.length}',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: bt.muted,
                  fontWeight: FontWeight.w600,
                  fontFeatures: Fonts.tabular,
                ),
          ),
        ),
        RowList(
          children: [
            for (final entry in whitelist)
              StatusRow(
                tone: entry.appId == kBackdropId ? Tone.idle : Tone.ok,
                icon: entry.appId == kBackdropId
                    ? Icons.home_rounded
                    : Icons.check_circle_rounded,
                title: entry.appId == kBackdropId
                    ? 'Home screen'
                    : entry.friendlyName,
                detail: entry.appId == kBackdropId
                    ? 'Always allowed'
                    : 'App ID ${entry.appId}',
                trailing: entry.appId == kBackdropId
                    ? Icon(
                        Icons.lock_outline_rounded,
                        size: Sizes.icon,
                        color: bt.faint,
                      )
                    : IconButton(
                        tooltip: 'Remove ${entry.friendlyName}',
                        icon: Icon(
                          Icons.close_rounded,
                          size: Sizes.icon,
                          color: bt.muted,
                        ),
                        onPressed: () => ref
                            .read(whitelistProvider.notifier)
                            .remove(entry.appId),
                      ),
              ),
          ],
        ),
      ],
    );
  }
}
