import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/whitelist_entry.dart';
import '../providers/providers.dart';

class WhitelistScreen extends ConsumerStatefulWidget {
  const WhitelistScreen({super.key});

  @override
  ConsumerState<WhitelistScreen> createState() =>
      _WhitelistScreenState();
}

class _WhitelistScreenState
    extends ConsumerState<WhitelistScreen> {
  Future<void> _addEntry() async {
    final idController = TextEditingController();
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add App to Whitelist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'App ID',
                hintText: 'e.g. 233637DE',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'App Name',
                hintText: 'e.g. YouTube',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && idController.text.isNotEmpty) {
      await ref.read(whitelistProvider.notifier).add(
            WhitelistEntry(
              appId: idController.text.trim(),
              friendlyName: nameController.text.trim().isEmpty
                  ? 'Unknown'
                  : nameController.text.trim(),
            ),
          );
    }

    idController.dispose();
    nameController.dispose();
  }

  Future<void> _queryCurrentApp() async {
    final tvService = ref.read(tvServiceProvider);
    final status = await tvService.getStatus();
    if (!mounted) return;

    if (status == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TV not reachable'),
        ),
      );
      return;
    }

    final whitelist = ref.read(whitelistProvider);
    final isWhitelisted = whitelist.any(
      (e) => e.appId == status.appId,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("What's Playing Now"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('App', status.appName),
            _infoRow('App ID', status.appId),
            _infoRow(
              'Idle',
              status.isIdle ? 'Yes' : 'No',
            ),
            const SizedBox(height: 8),
            if (status.isIdle)
              Text(
                'Home screen — always allowed.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                ),
              )
            else if (isWhitelisted)
              const Text(
                'This app is in the whitelist.',
                style: TextStyle(color: Colors.green),
              )
            else
              const Text(
                'Not in whitelist — will be stopped '
                'during lock mode.',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          if (!status.isIdle && !isWhitelisted)
            ElevatedButton(
              onPressed: () {
                ref.read(whitelistProvider.notifier).add(
                      WhitelistEntry(
                        appId: status.appId,
                        friendlyName: status.appName,
                      ),
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Added ${status.appName}',
                    ),
                  ),
                );
              },
              child: const Text('Add to Whitelist'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final whitelist = ref.watch(whitelistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Whitelist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.live_tv),
            tooltip: "What's playing now?",
            onPressed: _queryCurrentApp,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Apps not listed here will be stopped and '
              'muted during lock mode.',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: whitelist.isEmpty
                ? Center(
                    child: Text(
                      'No apps whitelisted.\n'
                      'All apps will be stopped in lock mode.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: whitelist.length,
                    itemBuilder: (context, index) {
                      final entry = whitelist[index];
                      final isBackdrop =
                          entry.appId == 'E8C28D3C';
                      return ListTile(
                        leading: Icon(
                          isBackdrop
                              ? Icons.home
                              : Icons.apps,
                          color: isBackdrop
                              ? Colors.grey
                              : Colors.green,
                        ),
                        title: Text(entry.friendlyName),
                        subtitle: Text(
                          entry.appId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        trailing: isBackdrop
                            ? Tooltip(
                                message: 'Cannot remove '
                                    'Home Screen',
                                child: Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  ref
                                      .read(
                                        whitelistProvider
                                            .notifier,
                                      )
                                      .remove(entry.appId);
                                },
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
