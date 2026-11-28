import 'package:flutter_test/flutter_test.dart';
import 'package:nilo_app/bottles.dart';
import 'package:nilo_app/daily.dart';

void main() {
  group('papyrus safety filter', () {
    test('allows a normal message', () => expect(papyrusFilterForTest('Hello from Cairo, how is your day?'), ''));
    test('blocks links', () => expect(papyrusFilterForTest('visit www.example.com'), isNotEmpty));
    test('blocks handles', () => expect(papyrusFilterForTest('find me @someone'), isNotEmpty));
    test('blocks chat-app links', () => expect(papyrusFilterForTest('t.me/abc'), isNotEmpty));
    test('blocks phone numbers', () => expect(papyrusFilterForTest('call 0123456789'), isNotEmpty));
    test('blocks Arabic-digit phone numbers', () => expect(papyrusFilterForTest('٠١٢٣٤٥٦٧٨٩'), isNotEmpty));
  });
  group('levels and flags', () {
    test('level 0 at zero xp', () => expect(levelOf(0), 0));
    test('level never goes down as xp grows', () {
      var last = 0;
      for (var xp = 0; xp < 2000; xp += 10) { final l = levelOf(xp); expect(l >= last, true); last = l; }
    });
    test('flag of EG', () => expect(flagOf('EG'), '\u{1F1EA}\u{1F1EC}'));
    test('flag of bad code is the globe', () => expect(flagOf(''), '🌍'));
  });
}
