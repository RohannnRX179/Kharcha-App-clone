import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kharcha/data/remote/supabase_client_provider.dart';
import 'package:kharcha/features/auth/screens/verify_email_screen.dart';

import 'widget_test_helpers.dart';

/// Covers the 2026-09-09 auth-email deep-link fix's permanent fallback:
/// "Already tapped the link? Sign in" (spec plan point 7) must always be
/// reachable, independent of whether the deep link itself ever lands.
void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/verify-email',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const Text('login')),
        GoRoute(path: '/signup', builder: (_, _) => const Text('signup')),
        GoRoute(
          path: '/verify-email',
          builder: (_, _) => const VerifyEmailScreen(email: 'a@b.com'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets(
    '"Already tapped the link? Sign in" signs out and goes to /login',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Already tapped the link? Sign in'));
      await tester.pumpAndSettle();

      verify(() => auth.signOut()).called(1);
      expect(find.text('login'), findsOneWidget);
    },
  );

  testWidgets('"Wrong address? Start again" signs out and goes to /signup', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Wrong address? Start again'));
    await tester.pumpAndSettle();

    verify(() => auth.signOut()).called(1);
    expect(find.text('signup'), findsOneWidget);
  });
}
