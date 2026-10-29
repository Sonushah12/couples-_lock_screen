import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pairlight/data/services/local_storage_service.dart';
import 'package:pairlight/data/repositories/couple_repository.dart';
import 'package:pairlight/data/models/moment.dart';
import 'package:pairlight/data/models/moment_page.dart';
import 'package:pairlight/data/models/couple_state.dart';

void main() {
  test('personal preferences cannot overwrite the shared anniversary', () {
    final result = mergeProfileState(
      {'name': 'Alex', 'moments': []},
      {
        'name': 'Alexandra',
        'anniversary': '2026-01-01',
        'relationship': 'Couple',
        'notifications': true,
      },
      {'anniversary': '2025-05-15', 'relationship': 'Married'},
    );
    expect(result['name'], 'Alexandra');
    expect(result['notifications'], isTrue);
    expect(result['anniversary'], '2025-05-15');
    expect(result['relationship'], 'Married');
  });
  test('an earlier partner’s answer is not shown as the current partner’s', () {
    final state = <String, dynamic>{
      'memberIds': ['alex', 'casey'],
      'answers': {'2026-10-09': 'My answer'},
      'answerAuthors': {'alex': 'My answer', 'jamie': 'Earlier answer'},
    };
    expect(activePartnerAnswer(state, 'alex', '2026-10-09'), isEmpty);
    (state['answerAuthors'] as Map)['casey'] = 'Current answer';
    expect(activePartnerAnswer(state, 'alex', '2026-10-09'), 'Current answer');
    expect(activePartnerAnswer(state, 'alex', '2026-10-10'), isEmpty);
    expect(activePartnerAnswer(state, 'intruder', '2026-10-09'), isEmpty);
  });
  test(
    'moments and profile survive repository recreation; deletion clears them',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final repository = CoupleRepository(service);
      final moment = Moment(
        id: '1',
        kind: 'note',
        content: 'Hello',
        createdAt: DateTime(2026, 10, 8),
        drawing: [
          [.1, .2, 123],
        ],
      );
      await repository.update({
        'name': 'Alex',
        'moments': [moment.toJson()],
      });
      final restored = CoupleRepository(service);
      expect(restored.state['name'], 'Alex');
      expect(restored.moments.single.content, 'Hello');
      expect(restored.moments.single.drawing!.first[0], .1);
      await restored.clear();
      expect(CoupleRepository(service).state, isEmpty);
    },
  );
  test(
    'a question left open overnight cannot overwrite the new day’s answer',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CoupleRepository(
        LocalStorageService(await SharedPreferences.getInstance()),
      );
      final oldDay = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      await expectLater(
        repository.saveAnswer('My old draft', questionDay: oldDay),
        throwsStateError,
      );
      expect(repository.state['answers'], isNull);
      await repository.saveAnswer(
        'Today’s answer',
        questionDay: repository.day,
      );
      expect(
        (repository.state['answers'] as Map)[repository.day],
        'Today’s answer',
      );
    },
  );
  test('countdown uses calendar days instead of elapsed hours', () {
    final countdown = Countdown('Visit', DateTime(2026, 10, 9));
    expect(countdown.daysFrom(DateTime(2026, 10, 8, 23, 59)), 1);
    expect(countdown.daysFrom(DateTime(2026, 10, 9, 12)), 0);
  });
  test(
    'incoming moments keep loaded history without restoring recent deletions',
    () {
      Moment item(int age) => Moment(
        id: 'moment_$age',
        kind: 'note',
        content: 'Moment $age',
        createdAt: DateTime.utc(2026, 10, 9).subtract(Duration(minutes: age)),
      );
      final previous = List.generate(52, (index) => item(index + 1));
      final retained = retainOlderMoments(
        latest: [item(0), ...previous.take(49)],
        previous: previous,
        older: previous.skip(50).toList(),
      );
      expect(retained.map((moment) => moment.id), [
        'moment_50',
        'moment_51',
        'moment_52',
      ]);
      final afterDeletion = retainOlderMoments(
        latest: previous
            .where((moment) => moment.id != 'moment_10')
            .take(50)
            .toList(),
        previous: previous,
        older: previous.skip(50).toList(),
      );
      expect(afterDeletion.map((moment) => moment.id), ['moment_52']);
    },
  );
}
