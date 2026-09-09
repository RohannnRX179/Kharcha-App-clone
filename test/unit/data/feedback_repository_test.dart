import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kharcha/core/errors/failure.dart';
import 'package:kharcha/data/remote/feedback_remote_ds.dart';
import 'package:kharcha/data/repositories/feedback_repository.dart';
import 'package:kharcha/domain/models/enums.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockFeedbackRemoteDataSource extends Mock
    implements FeedbackRemoteDataSource {}

void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late MockUser user;
  late MockFeedbackRemoteDataSource remote;
  late FeedbackRepository repository;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Kharcha',
      packageName: 'com.panicker.kharcha',
      version: '2.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    user = MockUser();
    remote = MockFeedbackRemoteDataSource();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.id).thenReturn('u1');
    repository = FeedbackRepository(client, remote);
  });

  test('submit inserts one row with the fields it was given', () async {
    when(() => remote.insert(any())).thenAnswer((_) async {});

    final result = await repository.submit(
      rating: 4,
      category: FeedbackCategory.bug,
      message: 'Sync banner flickers',
      householdId: 'h1',
    );

    expect(result.isOk, isTrue);
    final captured =
        verify(() => remote.insert(captureAny())).captured.single
            as Map<String, Object?>;
    expect(captured['user_id'], 'u1');
    expect(captured['household_id'], 'h1');
    expect(captured['rating'], 4);
    expect(captured['category'], 'bug');
    expect(captured['message'], 'Sync banner flickers');
    expect(captured['platform'], anyOf('android', 'ios'));
    expect(captured['app_version'], '2.0.0+1');
  });

  test('a network failure gets the feedback-specific message', () async {
    when(() => remote.insert(any()))
        .thenThrow(const SocketException('no route to host'));

    final result = await repository.submit(
      rating: null,
      category: FeedbackCategory.general,
      message: 'hello',
    );

    expect(result.failureOrNull, isA<NetworkFailure>());
    expect(
      result.failureOrNull!.message,
      'Sending feedback needs an internet connection.',
    );
  });

  test('no signed-in user is an AuthFailure, never a network call', () async {
    when(() => auth.currentUser).thenReturn(null);

    final result = await repository.submit(
      rating: 5,
      category: FeedbackCategory.praise,
      message: 'hello',
    );

    expect(result.failureOrNull, isA<AuthFailure>());
    verifyNever(() => remote.insert(any()));
  });
}
