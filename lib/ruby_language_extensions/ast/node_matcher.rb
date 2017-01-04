require "singleton"

module AstMatchable
end

class MatchAnyNode
  include Singleton
  include AstMatchable

  def matches?(_)
    {}
  end
end

class MatchAnyNodes
  include Singleton
  include AstMatchable

  def matches?(_)
    {}
  end
end

class MatchBind
  include AstMatchable
  def initialize(name, match)
    @name = name
    @match = match
  end

  def matches?(other)
    if @match.is_a?(AstMatchable)
      result = @match.matches?(other)
      return nil if result.nil?
      result.merge(@name => other)
    else
      if @match === other
        { @name => other }
      else
        nil
      end
    end
  end
end

class Parser::AST::Node
  def matches?(other)
    return nil unless type === other.type
    return nil unless children.last.is_a?(MatchAnyNodes) || children.size == other.children.size

    bindings = {}
    children.zip(other.children).each do |a, b|
      if a.is_a?(AstMatchable)
        result = a.matches?(b)
        return nil if result.nil?
        bindings.merge!(result)
      else
        return nil unless a === b
      end
    end
    bindings
  end
end
