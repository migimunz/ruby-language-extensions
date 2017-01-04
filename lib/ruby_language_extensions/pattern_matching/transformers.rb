class BaseTransformer < Parser::AST::Processor
  include Builder

  def transform(node)
    process(node)
  end

  def self.transform(ast, *args)
    self.new(*args).transform(ast)
  end

  def process_children(node)
    children = node.children.map do |c|
      if c.is_a?(Parser::AST::Node)
        process(c)
      else
        c
      end
    end
    s(node.type, *children)
  end
end

class WhitelistTransformer < Parser::AST::Processor
  include Builder
end

class BindingSubstitutor < BaseTransformer
  attr_accessor :bindings
  def initialize(bindings)
    @bindings = bindings
  end

  def on_send(node)
    if node.children[0] == nil && bindings.key?(node.children[1])
      s(:lvar, node.children[1])
    else
      process_children(node)
    end
  end
end

class ScopeTransformer < BaseTransformer
  attr_accessor :definitions

  def initialize
    @definitions = {}
  end

  def define(name, args, body)
    first_def = !definitions.key?(name)
    definitions[name] ||= []
    definitions[name] << [args, body]
    if first_def
      s(:patterndef, *name)
    else
      s(:remove)
    end
  end

  def on_block(node)
    receiver, args, body = node.children
    if is_let?(receiver)
      error(args, "Invalid argument declaration in pattern body") unless args == s(:args)
      name, args = deconstruct_name_and_args(receiver.children[2])
      define(name, args, body)
    else
      node
    end
  end

  def on_send(node)
    if is_let?(node)
      let_receiver, kwd, block = node.children
      error(node, "Invalid use of keyword `let`") unless let_receiver == nil
      receiver, args, body = block.children
      error(args, "Invalid argument declaration in pattern body") unless args == s(:args)
      name, args = deconstruct_name_and_args(receiver)
      define(name, args, body)
    else
      node
    end
  end

  def on_begin(node)
    s(:begin, *ScopeTransformer.new.transform_all(node.children))
  end

  def transform_all(nodes)
    transformed = nodes.map { |node| transform(node) }
    transformed.map do |node|
      if node.type == :patterndef
        generator = DefinitionGenerator.new(node.children, definitions[node.children])
        generator.generate
      elsif node.type == :remove
        nil
      else
        node
      end
    end.compact
  end

  def deconstruct_name_and_args(node)
    error(node) unless node.type == :send
    method_type = node.children[0] == s(:self) ? :class : :instance
    fname = [method_type, node.children[1]] # name is in form [:instance|:class, name]
    args = node.children[2..-1]
    return fname, args
  end

  def error(node, message = "")
    raise SyntaxError, "Error with #{node.type} on #{node.loc}. #{message}"
  end

  def is_let?(node)
    s(:send, nil, :let, any_nodes).matches?(node)
  end
end