// Copyright (c) 2012, Lukas Renggli <renggli@gmail.com>

/**
 * LISP parser definition.
 */
class LispParser extends LispGrammar {

  void initialize() {
    super.initialize();

    action('list', (each) => each[1]);

    action('cell', (each) => new Cons(each[0], each[1]));
    action('null', (each) => null);

    action('string', (each) => new String.fromCharCodes(each[1]));
    action('character escape', (each) => each[1].charCodeAt(0));
    action('character raw', (each) => each.charCodeAt(0));

    action('symbol', (each) => new Symbol(each));
    action('number', (each) {
      var floating = Math.parseDouble(each);
      var integral = floating.toInt();
      if (floating == integral && each.indexOf('.') == -1) {
        return integral;
      } else {
        return floating;
      }
    });
  }

}