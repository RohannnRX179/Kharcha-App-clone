import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kharcha/core/errors/failure.dart';
import 'package:kharcha/data/repositories/account_deletion_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late MockUser user;
  late MockFunctionsClient functions;
  late AccountDeletionRepository repository;

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    user = MockUser();
    functions = MockFunctionsClient();
    when(() => client.auth).thenReturn(auth);
    when(() => client.functions).thenReturn(functions);
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.email).thenReturn('a@b.com');
    repository = AccountDeletionRepository(client);
  });

  group('reauthenticate', () {
    test('returns Ok on a correct password', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      final result = await repository.reauthenticate('correct-password');

      expect(result.isOk, isTrue);
      verify(
        () => auth.signInWithPassword(
          email: 'a@b.com',
          password: 'correct-password',
        ),
      ).called(1);
    });

    test('maps a wrong password to a plain "Incorrect password."', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthException('Invalid login credentials'));

      final result = await repository.reauthenticate('wrong');

      expect(result.failureOrNull, isA<AuthFailure>());
      expect(result.failureOrNull!.message, 'Incorrect password.');
    });

    test('no signed-in user is an AuthFailure, never a network call', () async {
      when(() => auth.currentUser).thenReturn(null);

      final result = await repository.reauthenticate('anything');

      expect(result.failureOrNull, isA<AuthFailure>());
      verifyNever(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });
  });

  group('deleteAccount', () {
    test('returns Ok when the Edge Function succeeds', () async {
      when(() => functions.invoke('delete-account')).thenAnswer(
        (_) async => const FunctionResponse(data: {'ok': true}, status: 200),
      );

      final result = await repository.deleteAccount();

      expect(result.isOk, isTrue);
    });

    test('maps promote_someone_first to its spec-exact copy (F-18)', () async {
      when(() => functions.invoke('delete-account')).thenThrow(
        const FunctionsHttpException(
          status: 409,
          details: {'error': 'promote_someone_first'},
        ),
      );

      final result = await repository.deleteAccount();

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.message,
        "You're the only admin of your household. Make someone else an "
        'admin, or remove the other members first.',
      );
    });

    test(
      'a failed-to-send request gets the deletion-specific offline message',
      () async {
        when(
          () => functions.invoke('delete-account'),
        ).thenThrow(const FunctionsFetchException(details: 'no route to host'));

        final result = await repository.deleteAccount();

        expect(result.failureOrNull, isA<NetworkFailure>());
        expect(
          result.failureOrNull!.message,
          'Deleting your account needs an internet connection.',
        );
      },
    );

    test('an unrecognised error code falls back to UnknownFailure', () async {
      when(() => functions.invoke('delete-account')).thenThrow(
        const FunctionsHttpException(
          status: 500,
          details: {'error': 'lookup_failed'},
        ),
      );

      final result = await repository.deleteAccount();

      expect(result.failureOrNull, isA<UnknownFailure>());
    });
  });
}
