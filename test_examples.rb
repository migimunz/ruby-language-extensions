$LOAD_PATH.push(File.expand_path('./lib'))
require 'ruby_language_extensions'

Dir['examples/*.pruby'].each do |fname|
  parser = Parser::CurrentRuby.new
  buffer = Parser::Source::Buffer.new(fname)
  buffer.read
  ast, comments = parser.parse_with_comments(buffer)
  pp ast
  File.write(fname.sub('pruby', 'ruby'), Unparser.unparse(ScopeTransformer.new.transform(ast)))
end
