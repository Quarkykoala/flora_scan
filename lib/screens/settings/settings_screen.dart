import 'dart:ui';

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
    final selectedLocaleCode = currentAppLocale?.languageCode ??
        userProfileAsync.valueOrNull?.localeCode ??
        'en';

    return Scaffold(
      backgroundColor: const Color(0xFFE8F2EA),
      appBar: AppBar(
        title: const Text(
          'FloraScan Settings',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          const _Backdrop(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              _SectionCard(
                title: 'Account',
                child: userProfileAsync.when(
                  loading: () => const ListTile(
                    leading: CircularProgressIndicator(),
                    title: Text('Loading...'),
                  ),
                  error: (_, __) => const ListTile(
                    leading: Icon(Icons.error_outline),
                    title: Text('Error loading profile'),
                  ),
                  data: (profile) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                    leading: const Icon(Icons.account_circle_outlined, size: 36),
                    title: Text(profile?.isPremium == true ? 'Premium User' : 'Guest'),
                    subtitle: Text('Locale: $selectedLocaleCode'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Language',
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                  leading: const Icon(Icons.language_outlined),
                  title: Text(l10n.language),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(supportedLocales[selectedLocaleCode] ?? 'English'),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _showLanguagePicker(context, ref),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Privacy & Data',
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      secondary: const Icon(Icons.science_outlined),
                      title: Text(l10n.researchConsent),
                      subtitle: Text(l10n.researchConsentSubtitle),
                      activeThumbColor: const Color(0xFF35E37B),
                      value: userProfileAsync.valueOrNull?.researchConsent ?? true,
                      onChanged: (value) {
                        ref
                            .read(authNotifierProvider.notifier)
                            .updateResearchConsent(value);
                        ref.invalidate(userProfileProvider);
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(l10n.privacyPolicy),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Sync & Storage',
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      leading: const Icon(Icons.cloud_outlined),
                      title: Text(l10n.pendingUploads),
                      trailing: Text(
                        '$queueSize',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: queueSize > 0
                              ? AppTheme.warningAmber
                              : const Color(0xFF2ECC71),
                        ),
                      ),
                    ),
                    if (queueSize > 0)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 2),
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
                ),
              ),
              const SizedBox(height: 12),
              const _SectionCard(
                title: 'About',
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 2),
                  leading: Icon(Icons.eco_outlined),
                  title: Text('FloraScan'),
                  subtitle: Text('Version 1.0.0'),
                ),
              ),
            ],
          ),
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
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.52),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFD9E9D8),
                  Color(0xFFC6DFC4),
                  Color(0xFFB9D6B8),
                ],
              ),
            ),
          ),
          Positioned(top: -30, left: -40, child: _blob(const Color(0x664DAA55), 230)),
          Positioned(bottom: -70, right: -30, child: _blob(const Color(0x662F7D3A), 280)),
          Positioned(top: 280, right: -40, child: _blob(const Color(0x44D4ECCC), 200)),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
