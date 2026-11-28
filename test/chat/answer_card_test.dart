import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/features/chat/widgets/answer_card.dart';
import 'package:zoe_remind/rag/snippet.dart';

/// Takbuhin:  flutter test test/chat/answer_card_test.dart
///
/// R3: boldSpan — text ng sagot na may bold sa mga salitang tumama.
void main() {
  const style = TextStyle(fontSize: 16);

  List<(String, bool)> parts(TextSpan span) => [
        if (span.children == null) (span.text ?? '', false),
        for (final c in (span.children ?? const <InlineSpan>[]).cast<TextSpan>())
          (c.text ?? '', c.style?.fontWeight == FontWeight.w700),
      ];

  test('walang bold → isang TextSpan lang', () {
    final s = boldSpan('Wifi: ZoeHome', const [], style);
    expect(s.children, isNull);
    expect(s.text, 'Wifi: ZoeHome');
  });

  test('bold sa gitna at sa dulo', () {
    const text = 'Ito: Susi ng kotse';
    final s = boldSpan(text, const [SnippetSpan(5, 9), SnippetSpan(13, 18)], style);
    expect(parts(s), [
      ('Ito: ', false),
      ('Susi', true),
      (' ng ', false),
      ('kotse', true),
    ]);
    expect(s.toPlainText(), text);
  });

  test('mali / lampas / patong na span → nilalaktawan, hindi nagka-crash', () {
    const text = 'Wifi password';
    final s = boldSpan(
      text,
      const [SnippetSpan(0, 4), SnippetSpan(2, 6), SnippetSpan(9, 99), SnippetSpan(5, 5)],
      style,
    );
    expect(parts(s), [('Wifi', true), (' password', false)]);
    expect(s.toPlainText(), text);
  });
}