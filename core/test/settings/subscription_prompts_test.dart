import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('subscriptionPromptsAllowed', () {
    test('absent (null) → allowed', () {
      expect(subscriptionPromptsAllowed(null), isTrue);
    });

    test("'false' → allowed", () {
      expect(subscriptionPromptsAllowed('false'), isTrue);
    });

    test("only the exact string 'true' suppresses", () {
      expect(subscriptionPromptsAllowed('true'), isFalse);
    });

    test('empty string and malformed values fail toward allowed', () {
      expect(subscriptionPromptsAllowed(''), isTrue);
      expect(subscriptionPromptsAllowed('True'), isTrue);
      expect(subscriptionPromptsAllowed('TRUE'), isTrue);
      expect(subscriptionPromptsAllowed('1'), isTrue);
      expect(subscriptionPromptsAllowed('yes'), isTrue);
      expect(subscriptionPromptsAllowed('garbage'), isTrue);
    });
  });
}
