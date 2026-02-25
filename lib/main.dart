import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'config/theme.dart';
import 'config/router.dart';
import 'services/supabase_service.dart';
import 'services/offline_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize offline queue
  OfflineQueueService.initialize();

  runApp(
    const ProviderScope(
      child: FloraScanApp(),
    ),
  );
}

class FloraScanApp extends ConsumerWidget {
  const FloraScanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FloraScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('pt'),
        Locale('zh'),
        Locale('ja'),
        Locale('ko'),
        Locale('ar'),
        Locale('hi'),
        Locale('ru'),
        Locale('it'),
      ],
    );
  }
}
