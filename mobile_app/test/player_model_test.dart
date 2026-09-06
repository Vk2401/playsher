// A player's identity is what makes a game with strangers possible, so the
// rules that shape it are pinned here: what a handle looks like, what a card
// shows, and — most importantly — what never comes back from the API.

import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/player_model.dart';
import 'package:playsher_app/models/user_model.dart';

Map<String, dynamic> cardJson({
  String? username = 'ravi99',
  bool following = false,
  int? together,
}) =>
    {
      'id': 7,
      'name': 'Ravi Kumar',
      'username': username,
      'profile_picture': null,
      'is_following': following,
      if (together != null) 'games_together': together,
    };

Map<String, dynamic> profileJson() => {
      'id': 7,
      'name': 'Ravi Kumar',
      'username': 'ravi99',
      'bio': 'Left wing. Plays most Sundays.',
      'profile_picture': null,
      'member_since': '2026-09-14T10:00:00.000Z',
      'followers_count': 12,
      'following_count': 8,
      'games_hosted': 3,
      'games_played': 21,
      'sports': [
        {'id': 1, 'name': 'Football'},
        {'id': 2, 'name': 'Cricket'},
      ],
      'is_self': false,
      'is_following': true,
      'follows_you': true,
    };

void main() {
  group('PlayerCard', () {
    test('reads the identity the API sends', () {
      final p = PlayerCard.fromJson(cardJson());
      expect(p.id, 7);
      expect(p.name, 'Ravi Kumar');
      expect(p.username, 'ravi99');
      expect(p.handle, '@ravi99');
    });

    test('falls back to the display name when there is no handle', () {
      // Should not happen — every account is assigned one — but a bare "@" is
      // worse than a name.
      final p = PlayerCard.fromJson(cardJson(username: null));
      expect(p.handle, 'Ravi Kumar');
    });

    test('shows how well you know them when the API says', () {
      expect(PlayerCard.fromJson(cardJson(together: 3)).subtitle,
          '@ravi99 · 3 games together');
      expect(PlayerCard.fromJson(cardJson(together: 1)).subtitle,
          '@ravi99 · 1 game together');
      expect(PlayerCard.fromJson(cardJson()).subtitle, '@ravi99');
    });

    test('copyWith moves only the follow state', () {
      final p = PlayerCard.fromJson(cardJson()).copyWith(isFollowing: true);
      expect(p.isFollowing, isTrue);
      expect(p.username, 'ravi99');
      expect(p.id, 7);
    });

    test('initials cope with one name, many names and none', () {
      String initials(String name) =>
          PlayerCard.fromJson({'id': 1, 'name': name}).initials;
      expect(initials('Ravi Kumar Singh'), 'RS');
      expect(initials('Ravi'), 'R');
      expect(initials('   '), '?');
    });
  });

  group('PlayerProfile', () {
    test('reads the stats and the viewer relationship', () {
      final p = PlayerProfile.fromJson(profileJson());
      expect(p.followersCount, 12);
      expect(p.followingCount, 8);
      expect(p.gamesHosted, 3);
      expect(p.gamesPlayed, 21);
      expect(p.isFollowing, isTrue);
      expect(p.followsYou, isTrue);
      expect(p.isSelf, isFalse);
      expect(p.sports.map((s) => s.name), ['Football', 'Cricket']);
    });

    test('renders a member-since line, and nothing when unparseable', () {
      expect(PlayerProfile.fromJson(profileJson()).memberSinceLabel,
          'Playing since Sep 2026');
      final noDate = profileJson()..remove('member_since');
      expect(PlayerProfile.fromJson(noDate).memberSinceLabel, isNull);
      final junk = profileJson()..['member_since'] = 'not-a-date';
      expect(PlayerProfile.fromJson(junk).memberSinceLabel, isNull);
    });

    test('a follow updates the count without refetching', () {
      final p = PlayerProfile.fromJson(profileJson())
          .copyWith(isFollowing: false, followersCount: 11);
      expect(p.isFollowing, isFalse);
      expect(p.followersCount, 11);
      // Everything else survives the copy.
      expect(p.gamesPlayed, 21);
      expect(p.sports.length, 2);
    });

    test('asCard carries the same identity', () {
      final card = PlayerProfile.fromJson(profileJson()).asCard;
      expect(card.id, 7);
      expect(card.handle, '@ravi99');
      expect(card.isFollowing, isTrue);
    });
  });

  group('privacy', () {
    // The API does not send contact details on a player, and the models have
    // no field to hold one. This is the guard against that changing quietly.
    test('a player card has nowhere to put a phone number or email', () {
      final withPii = cardJson()
        ..['mobile'] = '+919876543210'
        ..['email'] = 'ravi@example.com';
      final p = PlayerCard.fromJson(withPii);
      expect(p.toString(), isNot(contains('9876543210')));
      expect(p.subtitle, isNot(contains('@example.com')));
      expect(p.handle, '@ravi99');
    });

    test('a profile has nowhere either', () {
      final withPii = profileJson()
        ..['mobile'] = '+919876543210'
        ..['email'] = 'ravi@example.com';
      final p = PlayerProfile.fromJson(withPii);
      expect(p.bio, isNot(contains('9876543210')));
      expect(p.handle, '@ravi99');
    });
  });

  group('UserModel — my own account', () {
    test('reads the handle, bio and social counts', () {
      final u = UserModel.fromJson({
        'id': 7,
        'name': 'Ravi Kumar',
        'username': 'ravi99',
        'bio': 'Left wing',
        'mobile': '+919876543210',
        'followers_count': 12,
        'following_count': 8,
        'games_hosted': 3,
        'games_played': 21,
      });
      expect(u.username, 'ravi99');
      expect(u.handle, '@ravi99');
      expect(u.bio, 'Left wing');
      expect(u.followersCount, 12);
      expect(u.gamesHosted, 3);
      // My own account does carry my number — it is mine.
      expect(u.mobile, '+919876543210');
    });

    test('reads profile_picture, which is what the API actually sends', () {
      final u = UserModel.fromJson(
          {'id': 1, 'name': 'A', 'mobile': 'x', 'profile_picture': 'http://p'});
      expect(u.avatar, 'http://p');
    });

    test('an account with no handle yet falls back to its name', () {
      final u = UserModel.fromJson({'id': 1, 'name': 'Ravi', 'mobile': 'x'});
      expect(u.username, isNull);
      expect(u.handle, 'Ravi');
    });
  });
}
