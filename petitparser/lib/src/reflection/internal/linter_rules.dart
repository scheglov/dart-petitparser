import '../../core/parser.dart';
import '../../parser/combinator/choice.dart';
import '../../parser/combinator/settable.dart';
import '../../parser/misc/failure.dart';
import '../../parser/repeater/repeating.dart';
import '../../parser/utils/resolvable.dart';
import '../analyzer.dart';
import '../linter.dart';

void unresolvedSettable(
    Analyzer analyzer, Parser parser, LinterCallback callback) {
  if (parser is SettableParser && parser.delegate is FailureParser) {
    callback(
        parser,
        LinterType.error,
        'Unresolved settable',
        'This error is typically a bug in the code where a recursive '
            'grammar was created with `undefined()` that has not been '
            'resolved.');
  }
}

void unnecessaryResolvable(
    Analyzer analyzer, Parser parser, LinterCallback callback) {
  if (parser is ResolvableParser) {
    callback(
        parser,
        LinterType.warning,
        'Unnecessary resolvable',
        'Resolvable parsers are used during construction of recursive '
            'grammars. While they typically dispatch to their delegate, '
            'they add unnecessary overhead that can be avoided by removing '
            'them before parsing using `resolve(parser)`.',
        () => analyzer.replaceAll(parser, parser.resolve()));
  }
}

void nestedChoice(Analyzer analyzer, Parser parser, LinterCallback callback) {
  if (parser is ChoiceParser) {
    final children = parser.children;
    for (var i = 0; i < children.length - 1; i++) {
      if (children[i] is ChoiceParser) {
        callback(
            parser,
            LinterType.info,
            'Nested choice',
            'The choice at index $i is another choice that adds unnecessary '
                'overhead that can be avoided by flattening it into the '
                'parent.',
            () => analyzer.replaceAll(
                parser,
                [
                  ...children.sublist(0, i - 1),
                  ...children[i].children,
                  ...children.sublist(i + 1),
                ].toChoiceParser()));
        return;
      }
    }
  }
}

void repeatedChoice(Analyzer analyzer, Parser parser, LinterCallback callback) {
  if (parser is ChoiceParser) {
    final children = parser.children;
    for (var i = 0; i < children.length; i++) {
      for (var j = 0; j < i; j++) {
        if (children[i].isEqualTo(children[j])) {
          callback(
              parser,
              LinterType.warning,
              'Repeated choice',
              'The choices at index $i and $j are is identical. The second '
                  'choice can never succeed and can therefor be removed.',
              () => analyzer.replaceAll(
                  parser,
                  [
                    ...children.sublist(0, j - 1),
                    ...children.sublist(j + 1),
                  ].toChoiceParser()));
        }
      }
    }
  }
}

void unreachableChoice(
    Analyzer analyzer, Parser parser, LinterCallback callback) {
  if (parser is ChoiceParser) {
    final children = parser.children;
    for (var i = 0; i < children.length - 1; i++) {
      if (analyzer.isNullable(children[i])) {
        callback(
            parser,
            LinterType.info,
            'Unreachable choice',
            'The choice at index $i is nullable, therefore the choices '
                'after that can never be reached and can be removed.',
            () => analyzer.replaceAll(
                parser, children.sublist(0, i).toChoiceParser()));
      }
    }
  }
}

void nullableRepeater(
    Analyzer analyzer, Parser parser, LinterCallback callback) {
  if (parser is RepeatingParser && analyzer.isNullable(parser.delegate)) {
    callback(
        parser,
        LinterType.error,
        'Nullable repeater',
        'A repeater that delegates to a nullable parser causes an infinite '
            'loop when parsing.');
  }
}

void leftRecursion(Analyzer analyzer, Parser parser, LinterCallback callback) {
  if (analyzer.cycleSet(parser).isNotEmpty) {
    callback(
        parser,
        LinterType.error,
        'Left recursion',
        'The parsers directly or indirectly refers to itself without consuming '
            'input: ${analyzer.cycleSet(parser)}. This causes an infinite loop '
            'when parsing.');
  }
}
