import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kharcha/data/remote/supabase_client_provider.dart';
import 'package:kharcha/features/auth/screens/reset_password_screen.dart';

import 'widget_test_helpers.dart';

/// Covers the 2026-09-09 auth-email deep-link fix's new screen: reached via
/// `AuthChangeEvent.passwordRecovery` (see `app.dart`), never navigated to
/// directly by any other screen.
void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;

  setUpAll(() {
    registerFallbackValue(UserAttributes());
  });

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/reset-password',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('dashboard')),
        GoRoute(
          path: '/reset-password',
          builder: (_, _) => const ResetPasswordScreen(),
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

  testWidgets('rejects a password under 6 characters', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'New password'),
      '123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm new password'),
      '123',
    );
    await tester.tap(find.text('Save password'));
    await tester.pump();

    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
    verifyNever(() => auth.updateUser(any()));
  });

  testWidgets('rejects mismatched passwords', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'New password'),
      'secret1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm new password'),
      'secret2',
    );
    await tester.tap(find.text('Save password'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    verifyNever(() => auth.updateUser(any()));
  });

  testWidgets(
    'a valid matching password calls updatePassword and leaves the screen',
    (tester) async {
      when(() => auth.updateUser(any()))
          .thenAnswer((_) async => UserResponse.fromJson({'id': 'u1'}));

      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'New password'),
        'newSecret1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm new password'),
        'newSecret1',
      );
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();

      verify(() => auth.updateUser(any())).called(1);
      expect(find.text('dashboard'), findsOneWidget);
    },
  );

  testWidgets('an auth failure shows its message inline and stays put', (
    tester,
  ) async {
    when(() => auth.updateUser(any()))
        .thenThrow(const AuthException('Session expired'));

    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'New password'),
      'newSecret1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm new password'),
      'newSecret1',
    );
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(find.text('Save password'), findsOneWidget);
    expect(find.text('dashboard'), findsNothing);
  });
}
