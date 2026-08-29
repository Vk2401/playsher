// The Discover feed's filters are a value type: they key a Riverpod family, so
// two filters describing the same feed must be `==`, and what they serialise
// is the contract with `GET /games`.

import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/game_filters.dart';

void main() {
  group('toQuery', () {
    test('a clean filter asks for the default feed', () {
      final q = const GameFilters().toQuery();
      expect(q, {'page': 1, 'sort': 'soonest'});
    });

    test('omits empty values rather than sending nulls', () {
      final q = const GameFilters(search: '   ', city: '  ').toQuery();
      expect(q.containsKey('search'), isFalse);
      expect(q.containsKey('city'), isFalse);
    });

    test('sends the date shorthand, not a computed range', () {
      // The server owns the app timezone, so "the weekend" is its call.
      final q = const GameFilters(when: GameWhen.weekend).toQuery();
      expect(q['when'], 'weekend');
      expect(q.containsKey('date_from'), isFalse);
    });

    test('anytime sends no date filter at all', () {
      expect(const GameFilters(when: GameWhen.anytime).toQuery()['when'],
          isNull);
    });

    test('carries every filter the sheet can set', () {
      final q = const GameFilters(
        sportId: 3,
        when: GameWhen.today,
        level: GameLevel.advanced,
        search: ' futsal ',
        city: 'Chennai',
        onlyOpen: true,
        excludeMine: true,
        sort: GameSort.newest,
        page: 2,
      ).toQuery();

      expect(q['sport_id'], 3);
      expect(q['when'], 'today');
      expect(q['level'], 'advanced');
      expect(q['search'], 'futsal');
      expect(q['city'], 'Chennai');
      expect(q['only_open'], 'true');
      expect(q['exclude_mine'], 'true');
      expect(q['sort'], 'newest');
      expect(q['page'], 2);
    });
  });

  group('equality', () {
    test('two identical filters share one fetch', () {
      const a = GameFilters(sportId: 2, when: GameWhen.today);
      const b = GameFilters(sportId: 2, when: GameWhen.today);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('changing a chip is a different key', () {
      expect(const GameFilters(sportId: 2),
          isNot(const GameFilters(sportId: 3)));
      expect(const GameFilters(when: GameWhen.today),
          isNot(const GameFilters(when: GameWhen.tomorrow)));
    });
  });

  group('copyWith', () {
    test('clears a sport rather than treating null as "unchanged"', () {
      const withSport = GameFilters(sportId: 4);
      expect(withSport.copyWith(sportId: null).sportId, 4);
      expect(withSport.copyWith(clearSport: true).sportId, isNull);
    });

    test('clears a level the same way', () {
      const withLevel = GameFilters(level: GameLevel.newbie);
      expect(withLevel.copyWith(level: null).level, GameLevel.newbie);
      expect(withLevel.copyWith(clearLevel: true).level, isNull);
    });
  });

  group('activeCount', () {
    test('counts only the filters hidden inside the sheet', () {
      // The sport strip and the search box are visible on the feed itself, so
      // badging them would tell the player something they can already see.
      expect(const GameFilters(sportId: 9, search: 'turf').activeCount, 0);
    });

    test('counts each sheet filter once', () {
      const f = GameFilters(
        when: GameWhen.weekend,
        level: GameLevel.beginner,
        onlyOpen: true,
        sort: GameSort.newest,
      );
      expect(f.activeCount, 4);
    });

    test('isClean is false as soon as anything narrows the feed', () {
      expect(const GameFilters().isClean, isTrue);
      expect(const GameFilters(sportId: 1).isClean, isFalse);
      expect(const GameFilters(search: 'x').isClean, isFalse);
      expect(const GameFilters(onlyOpen: true).isClean, isFalse);
    });
  });

  group('GameLevel', () {
    test('maps the API values the host form sends', () {
      expect(GameLevel.fromQuery('ultra_professional'),
          GameLevel.ultraProfessional);
      expect(GameLevel.fromQuery('intermediate'), GameLevel.intermediate);
    });

    test('drops an unknown level rather than guessing at one', () {
      expect(GameLevel.fromQuery('semi_pro'), isNull);
      expect(GameLevel.fromQuery(null), isNull);
    });

    test('still renders a level the app has never heard of', () {
      expect(GameLevel.labelFor('semi_pro'), 'semi_pro');
    });
  });
}
