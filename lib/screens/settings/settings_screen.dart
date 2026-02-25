import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_queue_service.dart';
import '../../providers/scan_provider.dart';

/// Supported locales with display names.
const Map<String, String> supportedLocales = {
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'pt': 'Português',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'ar': 'العربية',
  'hi': 'हिन्दी',
  'ru': 'Русский',
  'it': 'Italiano',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final queueSize = ref.watch(offlineQueueSizeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account section
          _SectionHeader(title: 'Account'),
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
                    title: Text(profile?.id.substring(0, 8) ?? 'Unknown'),
                    subtitle: Text('Locale: ${profile?.localeCode ?? 'en'}'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Language section
          _SectionHeader(title: 'Language'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('App Language'),
              subtitle: Text(
                supportedLocales[
                        userProfileAsync.valueOrNull?.localeCode ?? 'en'] ??
                    'English',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguagePicker(context, ref),
            ),
          ),
          const SizedBox(height: 16),

          // Privacy section
          _SectionHeader(title: 'Privacy & Data'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.science),
                  title: const Text('Research Consent'),
                  subtitle: const Text(
                    'Allow anonymized data for research',
                  ),
                  value:
                      userProfileAsync.valueOrNull?.researchConsent ?? true,
                  onChanged: (value) {
                    ref
                        .read(authNotifierProvider.notifier)
                        .updateResearchConsent(value);
                    ref.invalidate(userProfileProvider);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    // Open privacy policy
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sync section
          _SectionHeader(title: 'Sync & Storage'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('Pending Uploads'),
                  trailing: Text(
                    '$queueSize',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: queueSize > 0
                          ? AppTheme.warningAmber
                          : AppTheme.primaryGreen,
                    ),
                  ),
                ),
                if (queueSize > 0) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Force Sync Now'),
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

          // About section
          _SectionHeader(title: 'About'),
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

          // Sign out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout, color: AppTheme.errorRed),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: AppTheme.errorRed),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.errorRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select Language',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ...supportedLocales.entries.map((entry) {
            return ListTile(
              title: Text(entry.value),
              subtitle: Text(entry.key),
              onTap: () {
                ref
                    .read(authNotifierProvider.notifier)
                    .updateLocale(entry.key);
                ref.invalidate(userProfileProvider);
                Navigator.pop(ctx);
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
