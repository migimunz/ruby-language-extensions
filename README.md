# Language extensions for Ruby

This gem experiments with language extensions for Ruby - inspired by language extensions in Haskell. Given that Ruby is a very malleable language with a very ambiguous and DSL-happy syntax, a lot of language contructs can be built on top of Ruby without actually changing the lexer and parser or touching the interpreter.

The extensions work by parsing ruby code with the EDSLs using the Ruby parser gem, then transforming the AST with a series of transformers, and generating plain ruby code.

The end goal of this experiment is to create a static type checker for Ruby. However, that goal is still far off, and writing a type checker without support for pattern matching is likely to give me an aneurysm, so the first order of business is to write an extension that adds ML-like pattern matching to Ruby.

## Pattern matching

The extension currently in active development adds pattern matching similar to those in the ML-language family. It currently supports multiple pattern clauses per method, matching against exact values, arbitrarily nested arrays, and binding arbitrary parts of deconstructed objects to variables. Methods defined with `def` still work the same way, `let` introduces pattern matching.

### Example 1 - reverse function
```ruby
  let reverse([]) {
    []
  }

  let reverse([x, *xs]) {
    reverse(xs) + [x]
  }
```

The function above is defined with two clauses, one matches an empty array, the other deconstructs a non-empty array into head x and tail xs. Bound variables are local to the clause.

Pattern matching on arrays assumes array-like objects, and works for anything that responds to `#[]` (both for access and slicing), `#all?` and `#size`. For example, it can be used with ActiveRecord associations.

### Example 1 - generated code
```ruby
  def reverse(*args)
    if ((args.size == 1) && (args[0].respond_to?(:size) && (args[0].respond_to?(:[]) && (args[0].respond_to?(:all?) && (0 == args[0].size)))))
      []
    else
      if ((args.size == 1) && (args[0].respond_to?(:size) && (args[0].respond_to?(:[]) && (args[0].respond_to?(:all?) && ((1 <= args[0].size) && args[0][1..-1].any? do |tmp1|
        tmp1 == args[0][1..-1]
      end)))))
        xs = args[0][1..-1]
        x = args[0][0]
        reverse(xs) + [x]
      else
        raise(ArgumentError, "Inexhaustive pattern match in reverse")
      end
    end
  end
```

### Example 2 - matching classes and disjunction in patterns
```ruby
  let answer_for(question = CompositeQuestion, child_selectors = Hash | Array) {
    answer_for(question.descendant(*child_selectors))
  }

  let answer_for(question = Question) {
    answers.find { |answer| answer.question_id == question.id }
  }
```

The first clause matches if the first argument is a `CompositeQuestion`, and the second is either a `Hash` or an `Array`.

### Example 2 - generated code
```ruby
  def answer_for(*args)
    if ((args.size == 2) && (args[0].is_a?(CompositeQuestion) && (args[1].is_a?(Hash) || args[1].is_a?(Array))))
      question = args[0]
      child_selectors = args[1]
      answer_for(question.descendant(*child_selectors))
    else
      if ((args.size == 1) && args[0].is_a?(Question))
        question = args[0]
        answers.find do |answer|
          answer.question_id == question.id
        end
      else
        raise(ArgumentError, "Inexhaustive pattern match in answer_for")
      end
    end
  end
```

## Currently in progress

A lot is still to be done:
  - Hash and general object deconstruction is on the way.
  - Translating exception line and column positions to original code, instead of generated code.
  - Matching on passed blocks
  - A case-like construct for matching in function bodies

