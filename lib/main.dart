import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'services/storage.dart';
import 'state/providers.dart';
import 'ui/home/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (kIsWeb) {
    Hive.init(null);
  } else {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init('${dir.path}/lenggang');
  }
  final projects = await Hive.openBox<String>(ProjectStore.boxName);
  final settings = await Hive.openBox<String>(SettingsStore.boxName);
  runApp(
    ProviderScope(
      overrides: [
        projectStoreProvider.overrideWithValue(ProjectStore(HiveKv(projects))),
        settingsStoreProvider.overrideWithValue(
          SettingsStore(HiveKv(settings)),
        ),
      ],
      child: const LenggangApp(),
    ),
  );
}

class LenggangApp extends StatelessWidget {
  const LenggangApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lenggang',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const HomeScreen(),
  );
}
