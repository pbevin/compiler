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


class TestGenerator < BasicObject
  class Label
    attr_reader :name

    def initialize(name, generator)
      @gen = generator
      @name = name
    end

    def set!
      @gen.set_label(name)
    end

    def inspect
      @name
    end
  end

  attr_reader :code

  def initialize()
    @code = []
  end

  def method_missing(method, *args)
    @code << [method, *args]
  end

  def label
    Label.new(nextsym(), self)
  end

  def ==(other)
    code == other.code
  end

  def lines
    code.map do |method, *args|
      "#{method} #{args.map(&:inspect).join(', ')}"
    end.join("\n")
  end

  def nextsym()
    @nextsym ||= 0
    @nextsym += 1
    @nextsym
  end
end
