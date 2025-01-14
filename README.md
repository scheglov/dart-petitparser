PetitParser for Dart
====================

[![Pub Package](https://img.shields.io/pub/v/petitparser.svg)](https://pub.dev/packages/petitparser)
[![Build Status](https://github.com/petitparser/dart-petitparser/actions/workflows/dart.yml/badge.svg?branch=main)](https://github.com/petitparser/dart-petitparser/actions)
[![GitHub Issues](https://img.shields.io/github/issues/petitparser/dart-petitparser.svg)](https://github.com/petitparser/dart-petitparser/issues)
[![GitHub Forks](https://img.shields.io/github/forks/petitparser/dart-petitparser.svg)](https://github.com/petitparser/dart-petitparser/network)
[![GitHub Stars](https://img.shields.io/github/stars/petitparser/dart-petitparser.svg)](https://github.com/petitparser/dart-petitparser/stargazers)
[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/petitparser/dart-petitparser/main/LICENSE)

Grammars for programming languages are traditionally specified statically. They are hard to compose and reuse due to ambiguities that inevitably arise. PetitParser combines ideas from [scannerless parsing](https://en.wikipedia.org/wiki/Scannerless_parsing), [parser combinators](https://en.wikipedia.org/wiki/Parser_combinator), [parsing expression grammars](https://en.wikipedia.org/wiki/Parsing_expression_grammar) (PEG) and packrat parsers to model grammars and parsers as objects that can be reconfigured dynamically.

This library is open source, stable and well tested. Development happens on [GitHub](https://github.com/petitparser/dart-petitparser). Feel free to report issues or create a pull-request there. General questions are best asked on [StackOverflow](https://stackoverflow.com/questions/tagged/petitparser+dart).

The package is hosted on [dart packages](https://pub.dev/packages/petitparser). Up-to-date [API documentation](https://pub.dev/documentation/petitparser/latest/) is created with every release.


Tutorial
--------

Below are step-by-step instructions of how to write your first parser. More elaborate examples (JSON parser, LISP parser and evaluator, Prolog parser and evaluator, etc.) are included in the [example repository](https://github.com/petitparser/dart-petitparser/tree/main/petitparser_examples).


### Installation

Follow the installation instructions on [dart packages](https://pub.dev/packages/petitparser/install).

Import the package into your Dart code using:

```dart
import 'package:petitparser/petitparser.dart';
```


### Writing a Simple Grammar

Writing grammars with PetitParser is as simple as writing Dart code. For example, the following code creates a parser that can read identifiers (a letter followed by zero or more letter or digits):

```dart
final id = letter() & (letter() | digit()).star();
```

If you inspect the object `id` in the debugger, you'll notice that the code above builds a tree of parser objects:

- SequenceParser: This parser accepts the sequence of its child parsers.
  - CharacterParser: This parser accepts a single letter.
  - PossessiveRepeatingParser: This parser accepts zero or more times its child parsers.
    - ChoiceParser: This parser accepts the first of its succeeding child parsers, or otherwise fails.
      - CharacterParser: This parser accepts a single letter.
      - CharacterParser: This parser accepts a single digit.

The operators `&` and `|` are overloaded and create a sequence and a choice parser respectively. In some contexts it might be more convenient to use chained function calls, or the extension methods on lists. Both of the following parsers accept the same inputs as the parser above:

```dart
final id1 = letter().seq(letter().or(digit()).star());
final id2 = [letter(), [letter(), digit()].toChoiceParser().star()].toSequenceParser();
```

Note that the inferred type of the 3 parsers is not equivalent: Due to [github.com/dart-lang/language/issues/1557](https://github.com/dart-lang/language/issues/1557) the inferred type of sequence and choice parsers created with operators or chained function calls is `Parser<dynamic>`. The last variation created from lists has more specific type information.


### Parsing Some Input

To actually consume an input string we use the method `Parser.parse`:

```dart
final result1 = id.parse('yeah');
final result2 = id.parse('f12');
```

The method `Parser.parse` returns a `Result`, which is either an instance of `Success` or `Failure`. In both examples  we are successful and can retrieve the resulting value using `Success.value`:

```dart
print(result1.value);                   // ['y', ['e', 'a', 'h']]
print(result2.value);                   // ['f', ['1', '2']]
```

While it seems odd to get these nested arrays with characters as a return value, this is the default decomposition of the input into a parse-tree. We'll see in a while how that can be customized.

If we try to parse something invalid we get an instance of `Failure` and we can retrieve a descriptive error message using `Failure.message`:

```dart
final result3 = id.parse('123');
print(result3.message);                 // 'letter expected'
print(result3.position);                // 0
```

Trying to retrieve result by calling `Failure.value` would throw the exception `ParserError`. `Context.isSuccess` and `Context.isFailure` can be used to decide if the parsing was successful.

If you are only interested if a given string is valid you can use the helper method `Parser.accept`:

```dart
print(id.accept('foo'));                // true
print(id.accept('123'));                // false
```


### Different Kinds of Parsers

PetitParser provides a large set of ready-made parser that you can compose to consume and transform arbitrarily complex languages. Terminal parsers are the simplest. We've already seen a few of those:

- `any()` parses any character.
- `char('a')` (or `'a'.toParser()`) parses the character *a*.
- `digit()` parses a single digit from *0* to *9*.
- `letter()` parses a single letter from *a* to *z* and *A* to *Z*.
- `pattern('a-f')` (or `'a-f'.toParser(isPattern: true)`) parses a single character between *a* and *f*.
- `patternIgnoreCase('a-f')` (or `'a-f'.toParser(isPattern: true, caseInsensitive: true)`) parses a single character between *a* and *f*, or *A* and *F*.
- `string('abc')` (or `'abc'.toParser()`) parses the string *abc*.
- `stringIgnoreCase('abc')` (or `'abc'.toParser(caseInsensitive: true)`) parses the strings *Abc*, *aBC*, ...
- `word()` parses a single letter, digit, or the underscore character.

So instead of using the letter and digit predicate above, we could have written our identifier parser like this:

```dart
final id = letter() & pattern('a-zA-Z0-9').star();
```

The next set of parsers are used to combine other parsers together:

- `p1 & p2`, `p1.seq(p2)`, or `[p1, p2].toSequenceParser()` parse *p1* followed by *p2* (sequence).
- `p1 | p2`, `p1.or(p2)`, or `[p1, p2].toChoiceParser()` parse *p1*, if that doesn't work parse *p2* (ordered choice).
- `p.star()` parses *p* zero or more times.
- `p.plus()` parses *p* one or more times.
- `p.optional()` parses *p*, if possible.
- `p.and()` parses *p*, but does not consume its input.
- `p.not()` parses *p* and succeed when p fails, but does not consume its input.
- `p.end()` parses *p* and succeed at the end of the input.

The last type of parsers are actions or transformations we can use as follows:

- `p.map((value) => ...)` performs a transformation using the provided callback on the result of *p*.
- `p.where((value) => ...)` fails the parser *p* if its result does not satisfy the predicate.
- `p.pick(n)` returns the *n*-th element of the list *p* returns.
- `p.cast<T>()` casts the result of *p* to the type `T`.
- `p.flatten()` creates a string from the consumed input of *p*.
- `p.token()` creates a token from the result of *p*.
- `p.trim()` trims whitespaces before and after *p*.

To return a string of the parsed identifier, we can modify our parser like this:

```dart
final id = (letter() & pattern('a-zA-Z0-9').star()).flatten();
```

To conveniently find all matches in a given input string you can use `Parser.matchesSkipping`:

```dart
final matches = id.matchesSkipping('foo 123 bar4');
print(matches);                         // ['foo', 'bar4']
```

These are the basic elements to build parsers. There are a few more well documented and tested factory methods in the `Parser` class. If you want browse their documentation and tests.


### Writing a More Complicated Grammar

Now we are able to write a more complicated grammar for evaluating simple arithmetic expressions. Within a file we start with the grammar for a number (actually an integer):

```dart
final number = digit().plus().flatten().trim().map(int.parse);
```

Then we define the productions for addition and multiplication in order of precedence. Note that we instantiate the productions with undefined parsers upfront, because they recursively refer to each other. Later on we can resolve this recursion by setting their reference:

```dart
final term = undefined();
final prod = undefined();
final prim = undefined();

final add = (prod & char('+').trim() & term)
    .map((values) => values[0] + values[2]);
term.set(add | prod);

final mul = (prim & char('*').trim() & prod)
    .map((values) => values[0] * values[2]);
prod.set(mul | prim);

final parens = (char('(').trim() & term & char(')').trim())
    .map((values) => values[1]);
final number = digit().plus().flatten().trim().map(int.parse);
prim.set(parens | number);
```

To make sure our parser consumes all input we wrap it with the `end()` parser into the start production:

```dart
final parser = term.end();
```

That's it, now we can test our parser and evaluator:

```dart
parser.parse('1 + 2 * 3');              // 7
parser.parse('(1 + 2) * 3');            // 9
```


### Using Grammar Definitions

Defining and reusing complex grammars can be cumbersome, particularly if the grammar is large and recursive (such as the example above). The class `GrammarDefinition` provides the building block to conveniently define and build complex grammars with possibly hundreds of productions.

To create a new grammar definition subclass `GrammarDefinition`. In our case we call the class `ExpressionDefinition`. For every production create a new method returning the primitive parser defining it. The method called `start` is supposed to return the start production of the grammar. To refer to a production defined in the same definition use `ref0` with the function reference as the argument. The _0_ at the end of `ref0` means that the production reference isn't parametrized (zero argument production method).

```dart
class ExpressionDefinition extends GrammarDefinition {
  Parser start() => ref0(term).end();

  Parser term() => ref0(add) | ref0(prod);
  Parser add() => ref0(prod) & char('+').trim() & ref0(term);

  Parser prod() => ref0(mul) | ref0(prim);
  Parser mul() => ref0(prim) & char('*').trim() & ref0(prod);

  Parser prim() => ref0(parens) | ref0(number);
  Parser parens() => char('(').trim() & ref0(term) & char(')').trim();

  Parser number() => digit().plus().flatten().trim();
}
```

To create a parser with all the references correctly resolved call `build()`.

```dart
final definition = new ExpressionDefinition();
final parser = definition.build();
parser.parse('1 + 2 * 3');              // ['1', '+', ['2', '+', '3']]
```

Again, since this is plain Dart, common code refactorings such as renaming a production updates all references correctly. Also code navigation and code completion works as expected.

To attach custom production actions you might want to further subclass your grammar definition and override overriding the necessary productions defined in the superclass:

```dart
class EvaluatorDefinition extends ExpressionDefinition {
  Parser add() => super.add().map((values) => values[0] + values[2]);
  Parser mul() => super.mul().map((values) => values[0] * values[2]);
  Parser parens() => super.parens().castList<num>().pick(1);
  Parser number() => super.number().map((value) => int.parse(value));
}
```

Similarly, build the evaluator parser like so:

```dart
final definition = new EvaluatorDefinition();
final parser = definition.build();
parser.parse('1 + 2 * 3');              // 7
```

To use just a part of the parser you can specify the start production when building. For example, to reuse the number parser one would write:

```dart
final definition = new EvaluatorDefinition();
final parser = definition.build(start: definition.number);
parser.parse('42');                     // 42
```

This is just the surface of what `GrammarDefinition` can do, check out [the documentation](https://pub.dev/documentation/petitparser/latest/definition/GrammarDefinition-class.html) and the examples using it.


### Using the Expression Builder

Writing such expression parsers is pretty common and can be quite tricky to get right. To simplify things, PetitParser comes with a builder that can help you to define such grammars easily. It supports the definition of operator precedence; and prefix, postfix, left- and right-associative operators.

The following code creates the empty expression builder:

```dart
final builder = ExpressionBuilder();
```

Then we define the operator-groups in descending precedence. The highest precedence are the literal numbers themselves. This time we accept floating-point numbers, not just integers. In the same group we add support for the parenthesis:

```dart
builder.group()
  ..primitive(digit()
      .plus()
      .seq(char('.').seq(digit().plus()).optional())
      .flatten()
      .trim()
      .map((a) => num.tryParse(a)))
  ..wrapper(char('(').trim(), char(')').trim(), (String l, num a, String r) => a);
```

Then come the normal arithmetic operators. Note, that the action blocks receive both, the terms and the parsed operator in the order they appear in the parsed input:

```dart
// negation is a prefix operator
builder.group()
  ..prefix(char('-').trim(), (String op, num a) => -a);

// power is right-associative
builder.group()
  ..right(char('^').trim(), (num a, String op, num b) => math.pow(a, b));

// multiplication and addition are left-associative
builder.group()
  ..left(char('*').trim(), (num a, String op, num b) => a * b)
  ..left(char('/').trim(), (num a, String op, num b) => a / b);
builder.group()
  ..left(char('+').trim(), (num a, String op, num b) => a + b)
  ..left(char('-').trim(), (num a, String op, num b) => a - b);
```

Finally, we can build the parser:

```dart
final parser = builder.build().end();
```

After executing the above code we get an efficient parser that correctly evaluates expressions like:

```dart
parser.parse('-8');                     // -8
parser.parse('1+2*3');                  // 7
parser.parse('1*2+3');                  // 5
parser.parse('8/4/2');                  // 1
parser.parse('2^2^3');                  // 256
```

Check out [the documentation](https://pub.dev/documentation/petitparser/latest/expression/ExpressionBuilder-class.html) for more examples.


### Testing your Grammars

Real world grammar are typically large and complicated. PetitParser's architecture allows one to break down a grammar into manageable pieces, and develop and test each part individually before assembling the complete system.

Start the development and testing of a new grammar at the leaves (or tokens): write the parsers that read numbers, strings, and variables first; then continue with the expressions that can be built from these literals; and finally conclude with control structures, classes and other overarching constructs. At each step add tests and assert that the individual parsers behave as desired, so that you can be sure they also work when composing them to a larger grammar later.

Accessing and testing individual productions is simple: If you organize your grammar in your own code, make sure to expose parts of the grammar individually. If you use a `GrammarDefinition`, you can build individual productions using the optional start parameter of the `build` method. For example, to test the number production of the `EvaluatorDefinition` from above you would write:

```dart
test('number parsing', () {
  final definition = new EvaluatorDefinition();
  final parser = definition.build(start: definition.number);
  expect(parser.parse('42').value, 42);
});
```

Additionally, PetitParser provides a Linter that comes with a collection of predefined rules that can help you find common bugs or inefficient constructs in your code. Among other things, the analyzer detects infinite loops, unreachable parsers, repeated parsers, and unresolved parsers. For an up-to-date list of all available rules check the implementation at [linter_rules.dart](https://github.com/petitparser/dart-petitparser/blob/main/petitparser/lib/src/reflection/internal/linter_rules.dart).

To run the linter as part of your tests include the package `petitparser/reflection.dart`, call the `linter` function with the starting parser of your grammar, and assert that there are no findings. With the `EvaluatorDefinition` from above one would write:

```dart
test('detect common problems', () {
  final definition = new EvaluatorDefinition();
  final parser = definition.build();
  expect(linter(parser), isEmpty);
});
```

To exclude certain rules from being reported you can exclude certain rules, i.e. `linter(parser, excludedRules: {'Nested choice'})`.

Check out the extensive test suites of [PetitParser](https://github.com/petitparser/dart-petitparser/blob/main/petitparser/test) and [PetitParser Examples](https://github.com/petitparser/dart-petitparser/blob/main/petitparser_examples/test) for examples on testing.


Misc
----

[petitparser.github.io](https://petitparser.github.io/) contains up-to-date information about PetitParser.


### Examples

The package comes with a large collection of example grammars and language experiments ready to explore:

- [Dart](https://github.com/petitparser/dart-petitparser/tree/main/petitparser_examples/lib/src/dart) contains an experimental Dart grammar.
- [JSON](https://github.com/petitparser/dart-petitparser/tree/main/petitparser_examples/lib/src/json) contains a complete JSON grammar and parser.
- [Lisp](https://github.com/petitparser/dart-petitparser/tree/main/petitparser_examples/lib/src/lisp) contains a complete LISP grammar, parser and evaluator.
- [Prolog](https://github.com/petitparser/dart-petitparser/tree/main/petitparser_examples/lib/src/prolog) contains a basic Prolog grammar, parser and evaluator.
- [Smalltalk](https://github.com/petitparser/dart-petitparser/tree/main/petitparser_examples/lib/src/smalltalk) contains a complete Smalltalk grammar.
- [Uri](https://github.com/petitparser/dart-petitparser/blob/main/petitparser_examples/lib/uri.dart) contains a simple URI parser.

Furthermore, there are [numerous open source projects](https://pub.dev/packages?q=dependency:petitparser) using PetitParser:

- [apollovm](https://pub.dev/packages/apollovm), a simple VM that can parse, run and generate basic Dart and Java8 code.
- [equations](https://pub.dev/packages/equations) is an equation solving library.
- [expression_language](https://pub.dev/packages/expression_language) is a library for parsing and evaluating expressions.
- [expressions](https://pub.dev/packages/expressions) is a library to parse and evaluate simple expressions.
- [intl_translation](https://pub.dev/packages/intl_translation) provides internationalization and localization support to Dart.
- [json_path](https://pub.dev/packages/json_path) is an implementation of JSONPath expressions.
- [pem](https://pub.dev/packages/pem) encodes and decodes textual cryptographic keys.
- [puppeteer](https://pub.dev/packages/puppeteer) is a library to automate the Chrome browser.
- [query](https://pub.dev/packages/query) implements search queries with support for boolean groups, field scopes, ranges, etc.
- [xml](https://pub.dev/packages/xml) is a lightweight library for parsing, traversing, and querying XML documents.


### History

PetitParser was originally implemented in [Smalltalk](https://www.lukas-renggli.ch/smalltalk/helvetia/petitparser). Later on, as a mean to learn these languages, I reimplemented PetitParser in [Java](https://github.com/petitparser/java-petitparser) and [Dart](https://github.com/petitparser/dart-petitparser). The implementations are very similar in their API and the supported features. If possible, the implementations adopt best practises of the target language.


### Implementations

- [Dart](https://github.com/petitparser/dart-petitparser)
- [Java](https://github.com/petitparser/java-petitparser)
- [PHP](https://github.com/mindplay-dk/petitparserphp)
- [Smalltalk](https://www.lukas-renggli.ch/smalltalk/helvetia/petitparser)
- [Swift](https://github.com/philipparndt/swift-petitparser)
- [TypeScript](https://github.com/mindplay-dk/petitparser-ts)


### License

The MIT License, see [LICENSE](https://raw.githubusercontent.com/petitparser/dart-petitparser/main/LICENSE).
