import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/app_version_model.dart';
import 'package:playsher_app/widgets/update_required_dialog.dart';

Widget host(AppVersionCheck check, {Brightness brightness = Brightness.dark}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => UpdateRequiredDialog.show(context, check),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

const forced = AppVersionCheck(
  updateRequired: true,
  updateAvailable: true,
  latestVersion: '2.0.0',
  updateUrl: 'https://play.google.com/store/apps/details?id=com.playsher',
  releaseNotes: 'Payments were broken in 1.0.0.',
);

const optional = AppVersionCheck(
  updateAvailable: true,
  latestVersion: '1.5.0',
  updateUrl: 'https://play.google.com/store/apps/details?id=com.playsher',
);

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('AppVersionCheck', () {
    test('a malformed payload prompts nothing', () {
      final c = AppVersionCheck.fromJson(<String, dynamic>{});
      expect(c.updateRequired, isFalse);
      expect(c.updateAvailable, isFalse);
      expect(c.shouldPrompt, isFalse);
    });

    test('reads the API envelope', () {
      final c = AppVersionCheck.fromJson({
        'update_available': true,
        'update_required': true,
        'latest_version': '2.0.0',
        'min_supported_version': '1.5.0',
        'update_url': 'https://example.com',
        'release_notes': 'notes',
      });
      expect(c.updateRequired, isTrue);
      expect(c.latestVersion, '2.0.0');
      expect(c.updateUrl, 'https://example.com');
    });

    test('none never prompts', () {
      expect(AppVersionCheck.none.shouldPrompt, isFalse);
    });
  });

  group('UpdateRequiredDialog — forced', () {
    testWidgets('says the build is unsupported and shows no way out',
        (tester) async {
      await tester.pumpWidget(host(forced));
      await openDialog(tester);

      expect(find.text('Update required'), findsOneWidget);
      expect(find.textContaining('no longer supported'), findsOneWidget);
      // The escape hatch must not exist.
      expect(find.text('Later'), findsNothing);
      expect(find.text('Update now'), findsOneWidget);
    });

    testWidgets('a barrier tap does not dismiss it', (tester) async {
      await tester.pumpWidget(host(forced));
      await openDialog(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget);
    });

    testWidgets('the system back button does not dismiss it', (tester) async {
      await tester.pumpWidget(host(forced));
      await openDialog(tester);

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget,
          reason: 'PopScope must block back on a retired build (popped=$popped)');
    });

    testWidgets('shows the version and the release notes', (tester) async {
      await tester.pumpWidget(host(forced));
      await openDialog(tester);

      expect(find.text('Version 2.0.0'), findsOneWidget);
      expect(find.textContaining('Payments were broken'), findsOneWidget);
    });
  });

  group('UpdateRequiredDialog — optional', () {
    testWidgets('offers Later and reports the dismissal', (tester) async {
      await tester.pumpWidget(host(optional));
      await openDialog(tester);

      expect(find.text('Update available'), findsOneWidget);
      expect(find.textContaining('newer version'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('a barrier tap dismisses it', (tester) async {
      await tester.pumpWidget(host(optional));
      await openDialog(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('omits the notes block when there are none', (tester) async {
      await tester.pumpWidget(host(optional));
      await openDialog(tester);
      expect(find.text('Version 1.5.0'), findsOneWidget);
    });
  });

  group('UpdateRequiredDialog — UI rules', () {
    testWidgets('both actions meet the 44px touch minimum', (tester) async {
      await tester.pumpWidget(host(optional));
      await openDialog(tester);

      // find.byType matches the exact runtime type, so the concrete button
      // classes are what to look for — not their ButtonStyleButton base.
      final targets = <String, Finder>{
        'Later': find.widgetWithText(TextButton, 'Later'),
        'Update now': find.widgetWithText(ElevatedButton, 'Update now'),
      };
      targets.forEach((label, finder) {
        expect(finder, findsOneWidget, reason: 'could not find "$label"');
        final size = tester.getSize(finder);
        expect(size.height, greaterThanOrEqualTo(44.0),
            reason: '"$label" is only ${size.height}px tall');
      });
    });

    testWidgets('renders in light theme too', (tester) async {
      await tester.pumpWidget(host(forced, brightness: Brightness.light));
      await openDialog(tester);
      expect(find.text('Update required'), findsOneWidget);
    });

    testWidgets('long release notes do not overflow', (tester) async {
      await tester.pumpWidget(host(AppVersionCheck(
        updateRequired: true,
        latestVersion: '2.0.0',
        releaseNotes: List.filled(60, 'A long line of release notes.').join(' '),
      )));
      await openDialog(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
