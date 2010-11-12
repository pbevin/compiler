require 'rubygems'
require 'ruby_parser'
require 'sexp_processor'


class Compiler
  attr_reader :sexp

  def parse_file(filename)
    @sexp = RubyParser.new.parse(File.read(filename))
  end

  def parse(string)
    @sexp = RubyParser.new.parse(string)
  end

  def compile(generator)
    RubyProcessor.new(generator).compile_code_for(sexp)
  end

  class RubyProcessor < SexpProcessor
    attr_reader :g

    def initialize(generator)
      super()
      @regs = %w{ r0 r1 r2 r3 r4 r5 r6 r7 }.map(&:to_sym)
      @g = generator

      setup_sexp_processor
    end

    alias_method :compile_code_for, :process

    OP_MAP = {
      :+ => :add, :* => :mul, :- => :sub, :/ => :div,
      :< => :lt, :> => :gt, :<= => :le, :>= => :ge,
      :== => :eq, '!='.to_sym => :ne
    }

    def process_call(exp)
      receiver = exp.shift
      method = exp.shift
      params = exp.shift

      nparams = params.length - 1

      if op = OP_MAP[method]
        compile_code_for receiver
        with_temp_reg do |temp|
          compile_code_for params
          g.__send__(op, temp, working_reg)
        end
      else
        params.shift
        params.each do |p|
          compile_code_for p
          g.push working_reg
        end
        g.ldc :r0, nil
        g.ldc :r1, method.to_sym
        g.call nparams
      end
    end

    def process_arglist(exp)
      ret = []
      while arg = exp.shift
        ret << compile_code_for(arg)
      end
      ret
    end

    def process_str(exp)
      g.ldc working_reg, exp.shift
    end

    def process_lasgn(exp)
      var = exp.shift
      val = exp.shift

      compile_code_for val
      g.slv var, working_reg
    end

    def process_iasgn(exp)
      var = exp.shift
      val = exp.shift

      compile_code_for val
      g.siv var, working_reg
    end

    def process_lvar(exp)
      g.llv working_reg, exp.shift
    end

    def process_lit(exp)
      g.ldc working_reg, exp.shift
    end

    def process_block(exp)
      while stmt = exp.shift
        compile_code_for stmt
      end
    end

    def process_while(exp)
      cond = exp.shift
      body = exp.shift
      post = exp.shift

      loop_top = g.label
      loop_end = g.label

      loop_top.set!
      compile_code_for cond
      g.bf loop_end
      compile_code_for body
      g.bra loop_top
      loop_end.set!
    end

    def process_class(exp)
      class_name = exp.shift
      parent_class = exp.shift
      class_body = exp.shift

      if parent_class
        compile_code_for parent_class
        g.open_class class_name.to_s, working_reg
      else
        g.open_class class_name.to_s
      end
      compile_code_for class_body
      g.end_class
    end

    def process_const(exp)
      g.ldc working_reg, exp.shift
    end

    def process_scope(exp)
      compile_code_for exp.shift
    end

    def process_super(exp)
      g.super
    end

    def process_defn(exp)
      method_name = exp.shift
      args = exp.shift
      body = exp.shift

      g.open_method method_name.to_s
      compile_code_for args
      compile_code_for body
      g.end_method
    end

    def process_block_pass(exp)
      g.block_pass exp.shift.inspect
    end

    def process_cdecl(exp)
      raise exp.inspect
    end

    def process_args(exp)
      while lvar = exp.shift
        g.pop working_reg
        g.slv lvar
      end
    end

    private

    def setup_sexp_processor
      self.auto_shift_type = true
      self.expected = Object
      self.strict = true
    end

    def with_temp_reg
      var = @regs.shift
      yield(var)
      @regs.unshift var
    end

    def working_reg
      @regs[0]
    end
  end
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
    buf = ''
    code.map do |method, *args|
      buf << method.to_s
      if args.any?
        buf << ' '
        buf << args.map(&:inspect).join(', ')
      end
      buf << "\n"
    end
    return buf
  end

  def nextsym
    @nextsym ||= 0
    @nextsym += 1
  end
end
