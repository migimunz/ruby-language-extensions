# Given a name, and a list of clauses, generates
# a method definition.
class DefinitionGenerator
  attr_accessor :name, :clauses, :current_accessor
  include Builder

  def initialize(name, clauses)
    @name = name
    @clauses = clauses
  end

  def generate
    method_declaration do
      generate_clauses(clauses)
    end
  end

  private

  def generate_clauses(clauses)
    clause = clauses.first
    if clause
      args, body = clause
      cond, bindings = generate_pattern_match(args)
      s(:if, cond, substitute_bindings(body, bindings), generate_clauses(clauses[1..-1]))
    else
      pattern_match_error
    end
  end

  def pattern_match_error
    s(:send, nil, :raise,
      s(:const, nil, :ArgumentError),
      s(:str, "Inexhaustive pattern match in #{name.last}"))
  end

  def generate_pattern_match(args)
    PatternGenerator.new(args, safe_args_name).generate
  end

  def substitute_bindings(body, bindings)
    exprs = bindings.map do |var, expr|
      s(:lvasgn, var, expr)
    end
    body ||= s(:begin)
    body = BindingSubstitutor.transform(body, bindings)
    if body.type == :begin
      s(:begin, *(exprs + body.children))
    else
      s(:begin, *(exprs + [body]))
    end
  end

  def method_declaration
    if name.first == :class
      s(:defs, s(:self), name.last, s(:args, s(:restarg, safe_args_name)),
        yield
      )
    else
      s(:def, name.last, s(:args, s(:restarg, safe_args_name)),
        #TODO: Maybe wrap in rescue, and translate exceptions?
        yield
      )
    end
  end

  def safe_args_name
    # TODO: What if something references args in the body? Do an occurs check.
    @safe_args_name ||= :args
  end
end
