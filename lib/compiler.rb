require 'rubygems'
require 'ruby_parser'
require 'sexp_processor'


class Compiler
  attr_reader :sexp

  def parse(string)
    @sexp = RubyParser.new.parse(string)
  end

  def compile(generator)
    RubyProcessor.new(generator).process(sexp)
  end

  class RubyProcessor < SexpProcessor
    attr_reader :g

    def initialize(generator)
      super()
      @regs = (0..8).map { |n| "r#{n}".to_sym }
      @g = generator
      self.auto_shift_type = true
      self.expected = Object
      self.strict = true
    end

    def process_call(exp)
      receiver = exp.shift
      method = exp.shift
      params = exp.shift

      nparams = params.length - 1
      op = case method
      when :+
        :add
      when :*
        :mul
      when :-
        :sub
      when :<
        :lt
      end

      if op
        process receiver
        t = @regs.shift
        process params
        g.__send__(op, t, @regs[0])
      else
        params.shift
        params.each do |p|
          process p
          g.push @regs[0]
        end
        g.ldc :r0, nil
        g.ldc :r1, method.to_sym
        g.call nparams
      end
      @regs.unshift t
    end

    def process_arglist(exp)
      ret = []
      while arg = exp.shift
        ret << process(arg)
      end
      ret
    end

    def process_lasgn(exp)
      var = exp.shift
      val = exp.shift

      process val
      g.slv var, @regs[0]
    end

    def process_lvar(exp)
      g.llv @regs[0], exp.shift
    end

    def process_lit(exp)
      g.ldc @regs[0], exp.shift
    end

    def process_block(exp)
      while stmt = exp.shift
        process stmt
      end
    end

    def process_while(exp)
      cond = exp.shift
      body = exp.shift
      post = exp.shift

      loop_top = g.label
      loop_end = g.label

      loop_top.set!
      process cond
      g.bf loop_end
      process body
      g.bra loop_top
      loop_end.set!
    end
  end
end
