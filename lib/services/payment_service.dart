import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import 'analytics_service.dart';

class PaymentService {
  PaymentService._();

  static Uri _checkoutUri({
    required String source,
    String plan = 'premium_annual_29_99',
  }) {
    final base = AppConfig.dodoCheckoutBaseUrl;
    final success = AppConfig.dodoSuccessUrl;
    final cancel = AppConfig.dodoCancelUrl;

    if (base.isEmpty) {
      throw StateError(
        'DODO_CHECKOUT_BASE_URL missing. Set --dart-define=DODO_CHECKOUT_BASE_URL=...',
      );
    }

    final uri = Uri.parse(base);
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'plan': plan,
        'source': source,
        'success_url': success,
        'cancel_url': cancel,
      },
    );
  }

  static Future<bool> startPremiumCheckout({
    required BuildContext context,
    required String source,
  }) async {
    try {
      final uri = _checkoutUri(source: source);
      await AnalyticsService.track(
        'checkout_started',
        context: {
          'source': source,
          'provider': 'dodo',
          'url': uri.toString(),
        },
      );
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open checkout page')),
        );
      }
      return opened;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout unavailable: $error')),
        );
      }
      return false;
    }
  }
}

