Feature: Bytecode generation for expressions

  Scenario: Simple expression
    When I compile the expression "1+2"
    Then the sexp should be:
    """
    s(:call,
      s(:lit, 1),
      :+,
      s(:arglist, s(:lit, 2)))
    """
    And the bytecode should be:
    """
    ldc :r0, 1
    ldc :r1, 2
    add :r0, :r1
    """

  Scenario: More complex expression
    When I compile the expression "2 * (3+4) - 5"
    Then the sexp should be:
    """
    s(:call,
      s(:call, s(:lit, 2), :*,
        s(:arglist, s(:call, s(:lit, 3), :+, s(:arglist, s(:lit, 4))))),
      :-,
      s(:arglist, s(:lit, 5)))
    """
    And the bytecode should be:
    """
      ldc :r0, 2
      ldc :r1, 3
      ldc :r2, 4
      add :r1, :r2
      mul :r0, :r1
      ldc :r1, 5
      sub :r0, :r1
    """

  Scenario: Variable assignment
    When I compile the expression "x = 1"
    Then the sexp should be:
    """
    s(:lasgn, :x, s(:lit, 1))
    """
    And the bytecode should be:
    """
    ldc :r0, 1
    slv :x, :r0
    """

  Scenario: Variable increment
    When I compile the expression "x += 2"
    Then the sexp should be:
    """
    s(:lasgn, :x, s(:call, s(:lvar, :x), :+, s(:arglist, s(:lit, 2))))
    """
    And the bytecode should be:
    """
    llv :r0, :x
    ldc :r1, 2
    add :r0, :r1
    slv :x, :r0
    """

  Scenario: While loop
    When I compile the expression:
    """
    x = 0
    while x < 10
      x += 1
    end
    """
    Then the sexp should be:
    """
      s(:block,
        s(:lasgn, :x, s(:lit, 0)),
        s(:while,
          s(:call, s(:lvar, :x), :<, s(:arglist, s(:lit, 10))),
          s(:lasgn, :x, s(:call, s(:lvar, :x), :+, s(:arglist, s(:lit, 1)))),
                true))
    """
    And the bytecode should be:
    """
    ldc :r0, 0
    slv :x, :r0
    set_label 1
    llv :r0, :x
    ldc :r1, 10
    lt :r0, :r1
    bf 2
    llv :r0, :x
    ldc :r1, 1
    add :r0, :r1
    slv :x, :r0
    bra 1
    set_label 2
    """

  Scenario: puts() call
    When I compile the expression "puts 12"
    Then the sexp should be:
    """
    s(:call, nil, :puts, s(:arglist, s(:lit, 12)))
    """
    And the bytecode should be:
    """
    ldc :r0, 12
    push :r0
    ldc :r0, nil
    ldc :r1, :puts
    call 1
    """


  Scenario: require() call
    When I compile the expression:
    """
    require "rubygems"
    """
    Then the sexp should be:
    """
    s(:call, nil, :require, s(:arglist, s(:str, "rubygems")))
    """
    And the bytecode should be:
    """
    ldc :r0, "rubygems"
    push :r0
    ldc :r0, nil
    ldc :r1, :require
    call 1
    """

  Scenario: class declaration (empty)
    When I compile the expression:
    """
    class Person
    end
    """
    Then the sexp should be:
    """
    s(:class, :Person, nil, s(:scope))
    """
    And the bytecode should be:
    """
    open_class "Person"
    end_class
    """

  Scenario: class declaration (with a method)
    When I compile the expression:
    """
    class Person
      def hello(who)
        puts "Hello, " + who
      end
    end
    """
    Then the sexp should be:
    """
    s(:class, :Person, nil,
      s(:scope,
        s(:defn,
          :hello,
          s(:args, :who),
          s(:scope,
            s(:block,
              s(:call,
                nil,
                :puts,
                s(:arglist,
                  s(:call,
                    s(:str, "Hello, "),
                    :+,
                    s(:arglist, s(:lvar, :who))))))))))
    """
    And the bytecode should be:
    """
    open_class "Person"
    open_method "hello"
    pop :r0
    slv :who
    ldc :r0, "Hello, "
    llv :r1, :who
    add :r0, :r1
    push :r0
    ldc :r0, nil
    ldc :r1, :puts
    call 1
    end_method
    end_class
    """

  Scenario: Instance variable assignment
    When I compile the expression "@age = 22"
    Then the sexp should be:
    """
    s(:iasgn, :@age, s(:lit, 22))
    """
    And the bytecode should be:
    """
    ldc :r0, 22
    siv :@age, :r0
    """

