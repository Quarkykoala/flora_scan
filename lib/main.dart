import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'config/app_config.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'providers/followup_mission_provider.dart';
import 'providers/locale_provider.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/offline_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Validate configuration before proceeding
  AppConfig.validate();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize offline queue
  await OfflineQueueService.initialize();
  await NotificationService.initialize();

  runApp(
    const ProviderScope(
      child: FloraScanApp(),
    ),
  );
}

class FloraScanApp extends ConsumerStatefulWidget {
  const FloraScanApp({super.key});

  @override
  ConsumerState<FloraScanApp> createState() => _FloraScanAppState();
}

class _FloraScanAppState extends ConsumerState<FloraScanApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pendingFollowupMissionsProvider);
      unawaited(ref.read(pendingFollowupMissionsProvider.future));
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'FloraScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: locale,
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
