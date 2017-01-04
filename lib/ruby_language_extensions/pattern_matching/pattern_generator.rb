
class PatternGenerator < WhitelistTransformer
  attr_accessor :args, :bindings, :current_accessor, :args_name

  SUPPORTED_METHODS = {
    :| => :pattern_disjunction,
    :& => :pattern_conjuction
  }

  def initialize(args, args_name)
    @args = args
    @bindings = {}
    @current_accessor = nil
    @args_name = args_name
  end

  def with_accessor(new_accessor)
    old_accessor = current_accessor
    self.current_accessor = new_accessor
    ret = yield
    self.current_accessor = old_accessor
    return ret
  end

  def generate
    conditions = args.zip(0..args.size).map do |arg, n|
      with_accessor(arg_accessor(n)) do
        process(arg)
      end
    end
    pattern = join_conditions([args_size_condition(args.size)] + conditions)
    return pattern, bindings
  end

  def self.generate(args)
    self.new(args).generate
  end

  def args_size_condition(n)
    s(:send, s(:send, s(:lvar, args_name), :size), :==, s(:int, n))
  end

  def arg_accessor(n)
    s(:send, s(:lvar, args_name), :[], s(:int, n))
  end

  def error(node, message = "")
    raise SyntaxError, "Error with #{node.type} on #{node.loc}. #{message}"
  end

  def join_conditions(conds)
    return conds if conds.is_a?(Parser::AST::Node)
    conds
      .flatten
      .reject { |node| node == skip }
      .reverse
      .reduce { |a, b| s(:and, b, a) }
  end

  # Pattern transformations

  def on_send(node)
    receiver, meth, *args = node.children
    if SUPPORTED_METHODS.key?(meth)
      send(SUPPORTED_METHODS[meth], node)
    else
      error(node, "Invalid variable binding in pattern") unless args.size == 0 && receiver == nil
      bind_or_compare(meth)
    end
  end

  def bound_variable?(node)
    s(:send, nil, bind(var: Symbol)).matches?(node) ||
    s(:lval, bind(var: Symbol)).matches?(node)      ||
    s(:lvasgn, bind(var: Symbol), bind(subpattern: any_node)).matches?(node)
  end

  def pattern_disjunction(node)
    receiver, meth, *args = node.children
    error(node, "Invalid pattern disjunction") unless args.size == 1
    s(:or, join_conditions(process(receiver)), join_conditions(process(args.first)))
  end

  def pattern_conjuction(node)
    receiver, meth, *args = node.children
    error(node, "Invalid pattern conjuction") unless args.size == 1
    s(:and, join_conditions(process(receiver)), join_conditions(process(args.first)))
  end

  def on_lvar(node)
    bind_or_compare(node.children.first)
  end

  def bind_or_compare(var)
    return skip if var == :_
    if bindings.key?(var)
      s(:send, current_accessor, :==, bindings[var])
    else
      bindings[var] = current_accessor
      skip
    end
  end

  def on_lvasgn(node)
    var, pat = node.children
    error(node, "Variable #{var} is already bound in the pattern") if bindings.key?(var)
    bindings[var] = current_accessor
    process(pat)
  end

  def skip
    s(:true)
  end

  def process_literal(node)
    s(:send, node, :==, current_accessor)
  end

  def on_true(_)
    current_accessor
  end

  def on_false(_)
    s(:not, current_accessor)
  end

  def on_const(node)
    s(:send, current_accessor, :is_a?, node)
  end

  alias :on_int :process_literal
  alias :on_float :process_literal
  alias :on_str :process_literal
  alias :on_sym :process_literal
  alias :on_nil :process_literal

  # Match exact array
  def on_array(node)
    if is_rest_splat?(node)
      children = node.children[0..-2]
      precondition = s(:send, s(:int, children.size), :<=, s(:send, current_accessor, :size))
      postcondition = splat_binding(node)
    else
      postcondition = nil
      children = node.children
      precondition = s(:send, s(:int, children.size), :==, s(:send, current_accessor, :size))
    end
    processed = children.zip(0..children.size).map do |child, i|
      with_accessor(s(:send, current_accessor, :[], s(:int, i))) do
        process(child)
      end
    end
    conds = [*array_preconditions, precondition, *processed, postcondition].compact
    conds
  end

  def is_rest_splat?(node)
    node.children.last && node.children.last.type == :splat
  end

  def array_preconditions
    [s(:send, current_accessor, :respond_to?, s(:sym, :size)),
     s(:send, current_accessor, :respond_to?, s(:sym, :[])),
     s(:send, current_accessor, :respond_to?, s(:sym, :all?))]
  end

  def splat_binding(node)
    splat = node.children.last.children.first
    splat_accessor = s(:send, current_accessor, :[],
      s(:irange,
        s(:int, node.children.size - 1),
        s(:int, -1)))

    result = bound_variable?(splat) || {}
    with_accessor(splat_accessor) do
      bind_or_compare(result[:var]) if result.key?(:var)
      forall_pattern(result[:subpattern] || splat)
    end
  end

  def forall_pattern(node)
    argname = fresh_arg_name
    body = with_accessor(s(:lvar, argname)) do
      process(node)
    end
    s(:block,
      s(:send, current_accessor, :any?), s(:args, s(:arg, argname)),
        s(:begin, body))
  end

  def on_splat(node)
    error(node, "Invalid pattern")
  end

  def fresh_arg_name
    @counter ||= 0
    @counter += 1
    "tmp#{@counter}".to_sym
  end
end
