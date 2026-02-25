import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/supabase_service.dart';

/// Provides the current auth state (stream of auth changes).
final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseService.auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
});

/// Provides the current user profile from the users table.
final userProfileProvider =
    FutureProvider.autoDispose<UserProfile?>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;

  final data = await SupabaseService.getUserProfile(userId);
  if (data == null) return null;

  return UserProfile.fromJson(data);
});

/// Auth actions notifier.
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  /// Sign in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Sign up with email and password.
  Future<void> signUp({
    required String email,
    required String password,
    String localeCode = 'en',
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await SupabaseService.auth.signUp(
        email: email,
        password: password,
      );

      // Create user profile
      if (response.user != null) {
        await SupabaseService.upsertUserProfile({
          'id': response.user!.id,
          'locale_code': localeCode,
          'research_consent': true,
        });
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update locale.
  Future<void> updateLocale(String localeCode) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    await SupabaseService.updateUserProfile(userId, {
      'locale_code': localeCode,
    });
  }

  /// Update research consent.
  Future<void> updateResearchConsent(bool consent) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    await SupabaseService.updateUserProfile(userId, {
      'research_consent': consent,
    });
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier();
});
