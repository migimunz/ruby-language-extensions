module Builder
  def s(type, *children)
    Parser::AST::Node.new(type, children)
  end

  def build(node = nil, &block)
    result = if node
      self.instance_exec(*node.children, &block)
    else
      self.instance_exec(&block)
    end
    if result.is_a?(Array)
      s(:begin, *result)
    else
      result
    end
  end

  def any_node
    MatchAnyNode.instance
  end

  def any_nodes
    MatchAnyNodes.instance
  end

  def bind(name)
    if name.is_a?(Hash)
      MatchBind.new(name.keys.first, name.values.first)
    else
      MatchBind.new(name, any_node)
    end
  end
end