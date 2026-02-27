import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/scan_provider.dart';
import '../../services/offline_queue_service.dart';

const Map<String, String> supportedLocales = {
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'Deutsch',
  'pt': 'Portuguese',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'ar': 'Arabic',
  'hi': 'Hindi',
  'ru': 'Russian',
  'it': 'Italiano',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userProfileAsync = ref.watch(userProfileProvider);
    final currentAppLocale = ref.watch(appLocaleProvider);
    final queueSize = ref.watch(offlineQueueSizeProvider);
    final selectedLocaleCode =
        currentAppLocale?.languageCode ?? userProfileAsync.valueOrNull?.localeCode ?? 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Account'),
          Card(
            child: Column(
              children: [
                userProfileAsync.when(
                  loading: () => const ListTile(
                    leading: CircularProgressIndicator(),
                    title: Text('Loading...'),
                  ),
                  error: (_, __) => const ListTile(
                    leading: Icon(Icons.error),
                    title: Text('Error loading profile'),
                  ),
                  data: (profile) => ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.primaryGreen,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(profile?.id.substring(0, 8) ?? 'Guest'),
                    subtitle: Text('Locale: $selectedLocaleCode'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _SectionHeader(title: l10n.language),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              subtitle: Text(supportedLocales[selectedLocaleCode] ?? 'English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguagePicker(context, ref),
            ),
          ),
          const SizedBox(height: 16),

          const _SectionHeader(title: 'Privacy & Data'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.science),
                  title: Text(l10n.researchConsent),
                  subtitle: Text(l10n.researchConsentSubtitle),
                  value: userProfileAsync.valueOrNull?.researchConsent ?? true,
                  onChanged: (value) {
                    ref.read(authNotifierProvider.notifier).updateResearchConsent(value);
                    ref.invalidate(userProfileProvider);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: Text(l10n.privacyPolicy),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const _SectionHeader(title: 'Sync & Storage'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: Text(l10n.pendingUploads),
                  trailing: Text(
                    '$queueSize',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: queueSize > 0 ? AppTheme.warningAmber : AppTheme.primaryGreen,
                    ),
                  ),
                ),
                if (queueSize > 0) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: Text(l10n.forceSyncNow),
                    onTap: () {
                      OfflineQueueService.forceSync();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Syncing...')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          const _SectionHeader(title: 'About'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('FloraScan'),
                  subtitle: Text('Version 1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Licenses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(context: context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.language,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ...supportedLocales.entries.map((entry) {
            return ListTile(
              title: Text(entry.value),
              subtitle: Text(entry.key),
              onTap: () async {
                await ref.read(appLocaleProvider.notifier).setLocale(entry.key);
                await ref.read(authNotifierProvider.notifier).updateLocale(entry.key);
                ref.invalidate(userProfileProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
            );
          }),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
      ),
    );
  }
}
