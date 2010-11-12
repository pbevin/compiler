require 'compiler'
require 'sexp_processor'

When /^I compile the expression "([^"]*)"$/ do |string|
  @compiler = Compiler.new
  @compiler.parse(string)
end


When /^I compile the expression:$/ do |string|
  @compiler = Compiler.new
  @compiler.parse(string)
end

Then /^the sexp should be:$/ do |string|
  @compiler.sexp.should == eval(string)
end

Then /^the sexp should be$/ do |string|
  pending # express the regexp above with the code you wish you had
end

Then /^the bytecode should be:$/ do |string|
  g = TestGenerator.new
  @compiler.compile(g)

  g.lines.should == string.lines.map(&:strip).join("\n")
end

