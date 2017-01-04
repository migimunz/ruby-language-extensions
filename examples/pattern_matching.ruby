language(:pattern_matching)
class TestClass
  def bar(*args)
    if ((args.size == 2) && (args[0].is_a?(Fixnum) && args[1].is_a?(Fixnum)))
      a = args[0]
      b = args[1]
      a + b
    else
      raise(ArgumentError, "Inexhaustive pattern match in bar")
    end
  end
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
  def fixnum_list(*args)
    if ((args.size == 1) && (args[0].respond_to?(:size) && (args[0].respond_to?(:[]) && (args[0].respond_to?(:all?) && ((2 <= args[0].size) && (args[0][0].is_a?(Fixnum) && (args[0][1].is_a?(Fixnum) && args[0][2..-1].any? do |tmp1|
      tmp1.is_a?(Fixnum)
    end)))))))
      rest = args[0][2..-1]
      a = args[0][0]
      b = args[0][1]
    else
      raise(ArgumentError, "Inexhaustive pattern match in fixnum_list")
    end
  end
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
end