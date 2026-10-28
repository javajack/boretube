import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/providers.dart';
import 'providers/tv_providers.dart';
import 'tv/tv_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final prefs = await SharedPreferences.getInstance();
  final store = await TvStore.load(prefs: prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        tvStoreProvider.overrideWith((ref) => store),
      ],
      child: const BoretubeApp(),
    ),
  );
}
