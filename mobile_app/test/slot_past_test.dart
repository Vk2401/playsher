import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/slot_model.dart';

SlotModel slotAt(DateTime start) => SlotModel(
      id: 1,
      groundSportId: 1,
      slotDate:
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      slotStartTime:
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:00',
      slotEndTime: '23:59:00',
    );

void main() {
  group('SlotModel.hasStarted', () {
    test('a slot two hours ago today has started', () {
      final s = slotAt(DateTime.now().subtract(const Duration(hours: 2)));
      expect(s.hasStarted, isTrue);
    });

    test('a slot two hours from now today has not started', () {
      final s = slotAt(DateTime.now().add(const Duration(hours: 2)));
      expect(s.hasStarted, isFalse);
    });

    test('a slot on a past date has started', () {
      final s = slotAt(DateTime.now().subtract(const Duration(days: 1)));
      expect(s.hasStarted, isTrue);
    });

    test('a slot tomorrow morning has not started', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final s = slotAt(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 6));
      expect(s.hasStarted, isFalse);
    });

    test('a malformed row is shown rather than silently dropped', () {
      const s = SlotModel(
        id: 1,
        groundSportId: 1,
        slotDate: '',
        slotStartTime: '',
        slotEndTime: '',
      );
      expect(s.hasStarted, isFalse);
    });
  });
}
