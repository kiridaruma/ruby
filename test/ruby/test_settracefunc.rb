# frozen_string_literal: false
require 'test/unit'
EnvUtil.suppress_warning {require 'continuation'}

class TestSetTraceFunc < Test::Unit::TestCase
  def setup
    if defined?(RubyVM)
      @original_compile_option = RubyVM::InstructionSequence.compile_option
      RubyVM::InstructionSequence.compile_option = {
        :trace_instruction => true,
        :specialized_instruction => false
      }
    end
    @target_thread = Thread.current
  end

  def teardown
    set_trace_func(nil)
    if defined?(RubyVM)
      RubyVM::InstructionSequence.compile_option = @original_compile_option
    end
    @target_thread = nil
  end

  def target_thread?
    Thread.current == @target_thread
  end

  def test_c_call
    events = []
    name = "#{self.class}\##{__method__}"
    eval <<-EOF.gsub(/^.*?: /, ""), nil, name
     1: set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
     2:   events << [event, lineno, mid, klass] if file == name
     3: })
     4: x = 1 + 1
     5: set_trace_func(nil)
    EOF
    assert_equal(["c-return", 1, :set_trace_func, Kernel],
                 events.shift)
    assert_equal(["line", 4, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 4, :+, Integer],
                 events.shift)
    assert_equal(["c-return", 4, :+, Integer],
                 events.shift)
    assert_equal(["line", 5, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 5, :set_trace_func, Kernel],
                 events.shift)
    assert_equal([], events)
  end

  def test_c_return_no_binding
    binding = :none
    TracePoint.new(:c_return){|tp|
      binding = tp.binding
    }.enable{
      1.object_id
    }
    assert_nil(binding)
  end

  def test_c_call_no_binding
    binding = :none
    TracePoint.new(:c_call){|tp|
      binding = tp.binding
    }.enable{
      1.object_id
    }
    assert_nil(binding)
  end

  def test_c_call_removed_method
    # [Bug #19305]
    klass = Class.new do
      attr_writer :bar
      alias_method :set_bar, :bar=
      remove_method :bar=
    end

    obj = klass.new
    method_id = nil
    parameters = nil

    TracePoint.new(:c_call) { |tp|
      method_id = tp.method_id
      parameters = tp.parameters
    }.enable {
      obj.set_bar(1)
    }

    assert_equal(:bar=, method_id)
    assert_equal([[:req]], parameters)
  end

  def test_c_call_aliased_method
    # [Bug #20915]
    klass = Class.new do
      alias_method :new_method, :method
    end

    instance = klass.new
    parameters = nil

    TracePoint.new(:c_call) do |tp|
      parameters = tp.parameters
    end.enable { instance.new_method(:to_s) }

    assert_equal([[:req]], parameters)
  end

  def test_call
    events = []
    name = "#{self.class}\##{__method__}"
    eval <<-EOF.gsub(/^.*?: /, ""), nil, name
     1: set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
     2:   events << [event, lineno, mid, klass] if file == name
     3: })
     4: def add(x, y)
     5:   x + y
     6: end
     7: x = add(1, 1)
     8: set_trace_func(nil)
    EOF
    assert_equal(["c-return", 1, :set_trace_func, Kernel],
                 events.shift)
    assert_equal(["line", 4, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 4, :method_added, self.class],
                 events.shift)
    assert_equal(["c-return", 4, :method_added, self.class],
                 events.shift)
    assert_equal(["line", 7, __method__, self.class],
                 events.shift)
    assert_equal(["call", 4, :add, self.class],
                 events.shift)
    assert_equal(["line", 5, :add, self.class],
                 events.shift)
    assert_equal(["c-call", 5, :+, Integer],
                 events.shift)
    assert_equal(["c-return", 5, :+, Integer],
                 events.shift)
    assert_equal(["return", 6, :add, self.class],
                 events.shift)
    assert_equal(["line", 8, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 8, :set_trace_func, Kernel],
                 events.shift)
    assert_equal([], events)
  end

  def test_class
    events = []
    name = "#{self.class}\##{__method__}"
    eval <<-EOF.gsub(/^.*?: /, ""), nil, name
     1: set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
     2:   events << [event, lineno, mid, klass] if file == name
     3: })
     4: class Foo
     5:   def bar
     6:   end
     7: end
     8: x = Foo.new.bar
     9: set_trace_func(nil)
    EOF
    assert_equal(["c-return", 1, :set_trace_func, Kernel],
                 events.shift)
    assert_equal(["line", 4, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 4, :const_added, Module],
                 events.shift)
    assert_equal(["c-return", 4, :const_added, Module],
                 events.shift)
    assert_equal(["c-call", 4, :inherited, Class],
                 events.shift)
    assert_equal(["c-return", 4, :inherited, Class],
                 events.shift)
    assert_equal(["class", 4, nil, nil],
                 events.shift)
    assert_equal(["line", 5, nil, nil],
                 events.shift)
    assert_equal(["c-call", 5, :method_added, Module],
                 events.shift)
    assert_equal(["c-return", 5, :method_added, Module],
                 events.shift)
    assert_equal(["end", 7, nil, nil],
                 events.shift)
    assert_equal(["line", 8, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 8, :new, Class],
                 events.shift)
    assert_equal(["c-call", 8, :initialize, BasicObject],
                 events.shift)
    assert_equal(["c-return", 8, :initialize, BasicObject],
                 events.shift)
    assert_equal(["c-return", 8, :new, Class],
                 events.shift)
    assert_equal(["call", 5, :bar, Foo],
                 events.shift)
    assert_equal(["return", 6, :bar, Foo],
                 events.shift)
    assert_equal(["line", 9, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 9, :set_trace_func, Kernel],
                 events.shift)
    assert_equal([], events)

    self.class.class_eval do
      remove_const :Foo
    end
  end

  def test_return # [ruby-dev:38701]
    events = []
    name = "#{self.class}\##{__method__}"
    eval <<-EOF.gsub(/^.*?: /, ""), nil, name
     1: set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
     2:   events << [event, lineno, mid, klass] if file == name
     3: })
     4: def meth_return(a)
     5:   return if a
     6:   return
     7: end
     8: meth_return(true)
     9: meth_return(false)
    10: set_trace_func(nil)
    EOF
    assert_equal(["c-return", 1, :set_trace_func, Kernel],
                 events.shift)
    assert_equal(["line", 4, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 4, :method_added, self.class],
                 events.shift)
    assert_equal(["c-return", 4, :method_added, self.class],
                 events.shift)
    assert_equal(["line", 8, __method__, self.class],
                 events.shift)
    assert_equal(["call", 4, :meth_return, self.class],
                 events.shift)
    assert_equal(["line", 5, :meth_return, self.class],
                 events.shift)
    assert_equal(["return", 5, :meth_return, self.class],
                 events.shift)
    assert_equal(["line", 9, :test_return, self.class],
                 events.shift)
    assert_equal(["call", 4, :meth_return, self.class],
                 events.shift)
    assert_equal(["line", 5, :meth_return, self.class],
                 events.shift)
    assert_equal(["line", 6, :meth_return, self.class],
                 events.shift)
    assert_equal(["return", 6, :meth_return, self.class],
                 events.shift)
    assert_equal(["line", 10, :test_return, self.class],
                 events.shift)
    assert_equal(["c-call", 10, :set_trace_func, Kernel],
                 events.shift)
    assert_equal([], events)
  end

  def test_return2 # [ruby-core:24463]
    events = []
    name = "#{self.class}\##{__method__}"
    eval <<-EOF.gsub(/^.*?: /, ""), nil, name
     1: set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
     2:   events << [event, lineno, mid, klass] if file == name
     3: })
     4: def meth_return2
     5:   a = 5
     6:   return a
     7: end
     8: meth_return2
     9: set_trace_func(nil)
    EOF
    assert_equal(["c-return", 1, :set_trace_func, Kernel],
                 events.shift)
    assert_equal(["line", 4, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 4, :method_added, self.class],
                 events.shift)
    assert_equal(["c-return", 4, :method_added, self.class],
                 events.shift)
    assert_equal(["line", 8, __method__, self.class],
                 events.shift)
    assert_equal(["call", 4, :meth_return2, self.class],
                 events.shift)
    assert_equal(["line", 5, :meth_return2, self.class],
                 events.shift)
    assert_equal(["line", 6, :meth_return2, self.class],
                 events.shift)
    assert_equal(["return", 6, :meth_return2, self.class],
                 events.shift)
    assert_equal(["line", 9, :test_return2, self.class],
                 events.shift)
    assert_equal(["c-call", 9, :set_trace_func, Kernel],
                 events.shift)
    assert_equal([], events)
  end

  def test_raise
    events = []
    name = "#{self.class}\##{__method__}"
    eval <<-EOF.gsub(/^.*?: /, ""), nil, name
     1: set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
     2:   events << [event, lineno, mid, klass] if file == name
     3: })
     4: begin
     5:   raise TypeError, "error"
     6: rescue TypeError
     7: end
     8: set_trace_func(nil)
    EOF
    assert_equal(["c-return", 1, :set_trace_func, Kernel],
                 events.shift)
    assert_equal(["line", 5, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 5, :raise, Kernel],
                 events.shift)
    assert_equal(["c-call", 5, :exception, Exception],
                 events.shift)
    assert_equal(["c-call", 5, :initialize, Exception],
                 events.shift)
    assert_equal(["c-return", 5, :initialize, Exception],
                 events.shift)
    assert_equal(["c-return", 5, :exception, Exception],
                 events.shift)
    assert_equal(["c-return", 5, :raise, Kernel],
                 events.shift)
    assert_equal(["c-call", 5, :backtrace, Exception],
                 events.shift)
    assert_equal(["c-return", 5, :backtrace, Exception],
                 events.shift)
    assert_equal(["raise", 5, :test_raise, TestSetTraceFunc],
                 events.shift)
    assert_equal(["c-call", 6, :===, Module],
                 events.shift)
    assert_equal(["c-return", 6, :===, Module],
                 events.shift)
    assert_equal(["line", 8, __method__, self.class],
                 events.shift)
    assert_equal(["c-call", 8, :set_trace_func, Kernel],
                 events.shift)
    assert_equal([], events)
  end

  def test_break # [ruby-core:27606] [Bug #2610]
    events = []
    name = "#{self.class}\##{__method__}"
    eval <<-EOF.gsub(/^.*?: /, ""), nil, name
     1: set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
     2:   events << [event, lineno, mid, klass] if file == name
     3: })
     4: [1,2,3].any? {|n| n}
     8: set_trace_func(nil)
    EOF

    [["c-return", 1, :set_trace_func, Kernel],
     ["line", 4, __method__, self.class],
     ["c-call", 4, :any?, Array],
     ["line", 4, __method__, self.class],
     ["c-return", 4, :any?, Array],
     ["line", 5, __method__, self.class],
     ["c-call", 5, :set_trace_func, Kernel]].each.with_index{|e, i|
       assert_equal(e, events.shift, "mismatch on #{i}th trace")
    }
  end

  def test_invalid_proc
      assert_raise(TypeError) { set_trace_func(1) }
  end

  def test_raise_in_trace
    set_trace_func proc {raise rescue nil}
    assert_equal(42, (raise rescue 42), '[ruby-core:24118]')
  end

  def test_thread_trace
    events = {:set => [], :add => []}
    name = "#{self.class}\##{__method__}"
    prc = Proc.new { |event, file, lineno, mid, binding, klass|
      events[:set] << [event, lineno, mid, klass, :set] if file == name
    }
    prc = prc # suppress warning
    prc2 = Proc.new { |event, file, lineno, mid, binding, klass|
      events[:add] << [event, lineno, mid, klass, :add] if file == name
    }
    prc2 = prc2 # suppress warning

    th = Thread.new do
      th = Thread.current
      eval <<-EOF.gsub(/^.*?: /, ""), nil, name
       1: th.set_trace_func(prc)
       2: th.add_trace_func(prc2)
       3: class ThreadTraceInnerClass
       4:   def foo
       5:     _x = 1 + 1
       6:   end
       7: end
       8: ThreadTraceInnerClass.new.foo
       9: th.set_trace_func(nil)
      EOF
    end
    th.join

    [["c-return", 1, :set_trace_func, Thread, :set],
     ["line", 2, __method__, self.class, :set],
     ["c-call", 2, :add_trace_func, Thread, :set]].each do |e|
      assert_equal(e, events[:set].shift)
    end

    [["c-return", 2, :add_trace_func, Thread],
     ["line", 3, __method__, self.class],
     ["c-call", 3, :const_added, Module],
     ["c-return", 3, :const_added, Module],
     ["c-call", 3, :inherited, Class],
     ["c-return", 3, :inherited, Class],
     ["class", 3, nil, nil],
     ["line", 4, nil, nil],
     ["c-call", 4, :method_added, Module],
     ["c-return", 4, :method_added, Module],
     ["end", 7, nil, nil],
     ["line", 8, __method__, self.class],
     ["c-call", 8, :new, Class],
     ["c-call", 8, :initialize, BasicObject],
     ["c-return", 8, :initialize, BasicObject],
     ["c-return", 8, :new, Class],
     ["call", 4, :foo, ThreadTraceInnerClass],
     ["line", 5, :foo, ThreadTraceInnerClass],
     ["c-call", 5, :+, Integer],
     ["c-return", 5, :+, Integer],
     ["return", 6, :foo, ThreadTraceInnerClass],
     ["line", 9, __method__, self.class],
     ["c-call", 9, :set_trace_func, Thread]].each do |e|
      [:set, :add].each do |type|
        assert_equal(e + [type], events[type].shift)
      end
    end
    assert_equal([], events[:set])
    assert_equal([], events[:add])

    # cleanup
    self.class.class_eval do
      remove_const :ThreadTraceInnerClass
    end
  end

  def test_trace_defined_method
    events = []
    name = "#{self.class}\##{__method__}"
    eval <<-EOF.gsub(/^.*?: /, ""), nil, name
     1: class FooBar; define_method(:foobar){}; end
     2: fb = FooBar.new
     3: set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
     4:   events << [event, lineno, mid, klass] if file == name
     5: })
     6: fb.foobar
     7: set_trace_func(nil)
    EOF

    [["c-return", 3, :set_trace_func, Kernel],
     ["line", 6, __method__, self.class],
     ["call", 1, :foobar, FooBar],
     ["return", 1, :foobar, FooBar],
     ["line", 7, __method__, self.class],
     ["c-call", 7, :set_trace_func, Kernel]].each{|e|
      assert_equal(e, events.shift)
    }
  end

  def test_remove_in_trace
    bug3921 = '[ruby-dev:42350]'
    ok = false
    func = lambda{|e, f, l, i, b, k|
      # In parallel testing, unexpected events like IO operations may be traced,
      # so we filter out events here.
      next unless f == __FILE__
      set_trace_func(nil)
      ok = eval("self", b)
    }

    set_trace_func(func)
    assert_equal(self, ok, bug3921)
  end

  class << self
    define_method(:method_added, Module.method(:method_added))
  end

  def trace_by_tracepoint *trace_events
    events = []
    trace = nil
    xyzzy = nil
    _local_var = :outer
    raised_exc = nil
    method = :trace_by_tracepoint
    _get_data = lambda{|tp|
      case tp.event
      when :return, :c_return
        tp.return_value
      when :raise
        tp.raised_exception
      else
        :nothing
      end
    }
    _defined_class = lambda{|tp|
      klass = tp.defined_class
      begin
        # If it is singleton method, then return original class
        # to make compatible with set_trace_func().
        # This is very ad-hoc hack. I hope I can make more clean test on it.
        case klass.inspect
        when /Class:TracePoint/; return TracePoint
        when /Class:Exception/; return Exception
        else klass
        end
      rescue Exception => e
        e
      end if klass
    }

    trace = nil
    begin
    eval <<-EOF.gsub(/^.*?: /, ""), nil, 'xyzzy'
    1: trace = TracePoint.trace(*trace_events){|tp| next if !target_thread?
    2:   events << [tp.event, tp.lineno, tp.path, _defined_class.(tp), tp.method_id, tp.self, tp.binding&.eval("_local_var"), _get_data.(tp)] if tp.path == 'xyzzy'
    3: }
    4: [1].reverse_each{|;_local_var| _local_var = :inner
    5:   tap{}
    6: }
    7: class XYZZY
    8:   _local_var = :XYZZY_outer
    9:   def foo
   10:     _local_var = :XYZZY_foo
   11:     bar
   12:   end
   13:   def bar
   14:     _local_var = :XYZZY_bar
   15:     tap{}
   16:   end
   17: end
   18: xyzzy = XYZZY.new
   19: xyzzy.foo
   20: begin; raise RuntimeError; rescue RuntimeError => raised_exc; end
   21: trace.disable
    EOF
    self.class.class_eval{remove_const(:XYZZY)}
    ensure
      trace.disable if trace&.enabled?
    end

    answer_events = [
     #
     [:line,     4, 'xyzzy', self.class,  method,           self,        :outer, :nothing],
     [:c_call,   4, 'xyzzy', Array,       :reverse_each,    [1],         nil,    :nothing],
     [:line,     4, 'xyzzy', self.class,  method,           self,        nil,    :nothing],
     [:line,     5, 'xyzzy', self.class,  method,           self,        :inner, :nothing],
     [:c_return, 4, "xyzzy", Array,       :reverse_each,    [1],         nil, [1]],
     [:line,     7, 'xyzzy', self.class,  method,           self,        :outer, :nothing],
     [:c_call,   7, "xyzzy", Module,      :const_added,     TestSetTraceFunc, nil, :nothing],
     [:c_return, 7, "xyzzy", Module,      :const_added,     TestSetTraceFunc, nil, nil],
     [:c_call,   7, "xyzzy", Class,       :inherited,       Object,      nil, :nothing],
     [:c_return, 7, "xyzzy", Class,       :inherited,       Object,      nil, nil],
     [:class,    7, "xyzzy", nil,         nil,              xyzzy.class, nil,    :nothing],
     [:line,     8, "xyzzy", nil,         nil,              xyzzy.class, nil,    :nothing],
     [:line,     9, "xyzzy", nil,         nil,              xyzzy.class, :XYZZY_outer, :nothing],
     [:c_call,   9, "xyzzy", Module,      :method_added,    xyzzy.class, nil, :nothing],
     [:c_return, 9, "xyzzy", Module,      :method_added,    xyzzy.class, nil, nil],
     [:line,    13, "xyzzy", nil,         nil,              xyzzy.class, :XYZZY_outer, :nothing],
     [:c_call,  13, "xyzzy", Module,      :method_added,    xyzzy.class, nil, :nothing],
     [:c_return,13, "xyzzy", Module,      :method_added,    xyzzy.class, nil, nil],
     [:end,     17, "xyzzy", nil,         nil,              xyzzy.class, :XYZZY_outer, :nothing],
     [:line,    18, "xyzzy", TestSetTraceFunc, method,      self,        :outer, :nothing],
     [:c_call,  18, "xyzzy", Class,       :new,             xyzzy.class, nil, :nothing],
     [:c_call,  18, "xyzzy", BasicObject, :initialize,      xyzzy,       nil, :nothing],
     [:c_return,18, "xyzzy", BasicObject, :initialize,      xyzzy,       nil, nil],
     [:c_return,18, "xyzzy", Class,       :new,             xyzzy.class, nil, xyzzy],
     [:line,    19, "xyzzy", TestSetTraceFunc, method,      self, :outer, :nothing],
     [:call,     9, "xyzzy", xyzzy.class, :foo,             xyzzy,       nil,  :nothing],
     [:line,    10, "xyzzy", xyzzy.class, :foo,             xyzzy,       nil,  :nothing],
     [:line,    11, "xyzzy", xyzzy.class, :foo,             xyzzy,       :XYZZY_foo, :nothing],
     [:call,    13, "xyzzy", xyzzy.class, :bar,             xyzzy,       nil, :nothing],
     [:line,    14, "xyzzy", xyzzy.class, :bar,             xyzzy,       nil, :nothing],
     [:line,    15, "xyzzy", xyzzy.class, :bar,             xyzzy,       :XYZZY_bar, :nothing],
     [:return,  16, "xyzzy", xyzzy.class, :bar,             xyzzy,       :XYZZY_bar, xyzzy],
     [:return,  12, "xyzzy", xyzzy.class, :foo,             xyzzy,       :XYZZY_foo, xyzzy],
     [:line,    20, "xyzzy", TestSetTraceFunc, method,      self,        :outer, :nothing],
     [:c_call,  20, "xyzzy", Kernel,      :raise,           self,        nil, :nothing],
     [:c_call,  20, "xyzzy", Exception,   :exception,       RuntimeError, nil, :nothing],
     [:c_call,  20, "xyzzy", Exception,   :initialize,      raised_exc,  nil, :nothing],
     [:c_return,20, "xyzzy", Exception,   :initialize,      raised_exc,  nil, raised_exc],
     [:c_return,20, "xyzzy", Exception,   :exception,       RuntimeError, nil, raised_exc],
     [:c_return,20, "xyzzy", Kernel,      :raise,           self,        nil, nil],
     [:c_call,  20, "xyzzy", Exception,   :backtrace,       raised_exc,  nil, :nothing],
     [:c_return,20, "xyzzy", Exception,   :backtrace,       raised_exc,  nil, nil],
     [:raise,   20, "xyzzy", TestSetTraceFunc, :trace_by_tracepoint, self, :outer, raised_exc],
     [:c_call,  20, "xyzzy", Module,      :===,             RuntimeError, nil, :nothing],
     [:c_return,20, "xyzzy", Module,      :===,             RuntimeError, nil, true],
     [:line,    21, "xyzzy", TestSetTraceFunc, method,      self,        :outer, :nothing],
     ]

    return events, answer_events
  end

  def test_tracepoint
    events1, answer_events = *trace_by_tracepoint(:line, :class, :end, :call, :return, :c_call, :c_return, :raise)

    ms = [events1, answer_events].map{|evs|
      evs.map{|e|
        "#{e[0]} - #{e[2]}:#{e[1]} id: #{e[4]}"
      }
    }

    if false # show all events
      printf(" %-60s | %-60s\n", "actual", "expected")
      ms[0].zip(ms[1]){|a, b|
        printf("%s%-60s | %-60s\n", a==b ? ' ' : '!', a, b)
      }
    end

    mesg = ms[0].zip(ms[1]).map{|a, b|
      if a != b
        "actual: #{a} <-> expected: #{b}"
      end
    }.compact.join("\n")

    answer_events.zip(events1){|answer, event|
      assert_equal answer, event, mesg
    }

    [:line, :class, :end, :call, :return, :c_call, :c_return, :raise].each{|event|
      events1, answer_events = *trace_by_tracepoint(event)
      answer_events.find_all{|e| e[0] == event}.zip(events1){|answer_line, event_line|
        assert_equal answer_line, event_line
      }
    }
  end

  # Bug #18264
  def test_tracepoint_memory_leak
    assert_no_memory_leak([], <<-PREP, <<-CODE, rss: true)
code = proc { TracePoint.new(:line) { } }
1_000.times(&code)
PREP
1_000_000.times(&code)
CODE
  end

  def test_tracepoint_bmethod_memory_leak
    assert_no_memory_leak([], '', "#{<<~"begin;"}\n#{<<~'end;'}", "[Bug #20194]", rss: true)
      obj = Object.new
      obj.define_singleton_method(:foo) {}
      bmethod = obj.method(:foo)
      tp = TracePoint.new(:return) {}
    begin;
      1_000_000.times do
        tp.enable(target: bmethod) {}
      end
    end;
  end

  def trace_by_set_trace_func
    events = []
    trace = nil
    trace = trace
    xyzzy = nil
    xyzzy = xyzzy
    _local_var = :outer
    method = :trace_by_set_trace_func
    raised_exc = nil

    eval <<-EOF.gsub(/^.*?: /, ""), nil, 'xyzzy'
    1: set_trace_func(lambda{|event, file, line, id, binding, klass|
    2:   events << [event, line, file, klass, id, binding&.eval('self'), binding&.eval("_local_var")] if file == 'xyzzy'
    3: })
    4: [1].map!{|;_local_var| _local_var = :inner
    5:   tap{}
    6: }
    7: class XYZZY
    8:   _local_var = :XYZZY_outer
    9:   def foo
   10:     _local_var = :XYZZY_foo
   11:     bar
   12:   end
   13:   def bar
   14:     _local_var = :XYZZY_bar
   15:     tap{}
   16:   end
   17: end
   18: xyzzy = XYZZY.new
   19: xyzzy.foo
   20: begin; raise RuntimeError; rescue RuntimeError => raised_exc; end
   21: set_trace_func(nil)
    EOF
    self.class.class_eval{remove_const(:XYZZY)}

    answer_events = [
     #
     [:c_return, 1, "xyzzy", TracePoint,  :trace,           TracePoint,  nil,  nil],
     [:line,     4, 'xyzzy', self.class,  method,           self,        :outer, :nothing],
     [:c_call,   4, 'xyzzy', Integer,     :times,           1,           nil, nil],
     [:line,     4, 'xyzzy', self.class,  method,           self,        nil,    :nothing],
     [:line,     5, 'xyzzy', self.class,  method,           self,        :inner, :nothing],
     [:c_return, 4, "xyzzy", Integer,     :times,           1,           nil, nil],
     [:line,     7, 'xyzzy', self.class,  method,           self,        :outer, :nothing],
     [:c_call,   7, "xyzzy", Class,       :inherited,       Object,      nil, nil],
     [:c_return, 7, "xyzzy", Class,       :inherited,       Object,      nil, nil],
     [:c_call,   7, "xyzzy", Class,       :const_added,     Object,      nil, nil],
     [:c_return, 7, "xyzzy", Class,       :const_added,     Object,      nil, nil],
     [:class,    7, "xyzzy", nil,         nil,              xyzzy.class, nil,    :nothing],
     [:line,     8, "xyzzy", nil,         nil,              xyzzy.class, nil,    :nothing],
     [:line,     9, "xyzzy", nil,         nil,              xyzzy.class, :XYZZY_outer, :nothing],
     [:c_call,   9, "xyzzy", Module,      :method_added,    xyzzy.class, nil, nil],
     [:c_return, 9, "xyzzy", Module,      :method_added,    xyzzy.class, nil, nil],
     [:line,    13, "xyzzy", nil,         nil,              xyzzy.class, :XYZZY_outer, :nothing],
     [:c_call,  13, "xyzzy", Module,      :method_added,    xyzzy.class, nil, nil],
     [:c_return,13, "xyzzy", Module,      :method_added,    xyzzy.class, nil, nil],
     [:end,     17, "xyzzy", nil,         nil,              xyzzy.class, :XYZZY_outer, :nothing],
     [:line,    18, "xyzzy", TestSetTraceFunc, method,      self,        :outer, :nothing],
     [:c_call,  18, "xyzzy", Class,       :new,             xyzzy.class, nil, nil],
     [:c_call,  18, "xyzzy", BasicObject, :initialize,      xyzzy,       nil, nil],
     [:c_return,18, "xyzzy", BasicObject, :initialize,      xyzzy,       nil, nil],
     [:c_return,18, "xyzzy", Class,       :new,             xyzzy.class, nil, nil],
     [:line,    19, "xyzzy", TestSetTraceFunc, method,      self, :outer, :nothing],
     [:call,     9, "xyzzy", xyzzy.class, :foo,             xyzzy,       nil,  :nothing],
     [:line,    10, "xyzzy", xyzzy.class, :foo,             xyzzy,       nil,  :nothing],
     [:line,    11, "xyzzy", xyzzy.class, :foo,             xyzzy,       :XYZZY_foo, :nothing],
     [:call,    13, "xyzzy", xyzzy.class, :bar,             xyzzy,       nil, :nothing],
     [:line,    14, "xyzzy", xyzzy.class, :bar,             xyzzy,       nil, :nothing],
     [:line,    15, "xyzzy", xyzzy.class, :bar,             xyzzy,       :XYZZY_bar, :nothing],
     [:return,  16, "xyzzy", xyzzy.class, :bar,             xyzzy,       :XYZZY_bar, xyzzy],
     [:return,  12, "xyzzy", xyzzy.class, :foo,             xyzzy,       :XYZZY_foo, xyzzy],
     [:line,    20, "xyzzy", TestSetTraceFunc, method,      self,        :outer, :nothing],
     [:c_call,  20, "xyzzy", Kernel,      :raise,           self,        nil, nil],
     [:c_call,  20, "xyzzy", Exception,   :exception,       RuntimeError, nil, nil],
     [:c_call,  20, "xyzzy", Exception,   :initialize,      raised_exc,  nil, nil],
     [:c_return,20, "xyzzy", Exception,   :initialize,      raised_exc,  nil, nil],
     [:c_return,20, "xyzzy", Exception,   :exception,       RuntimeError, nil, nil],
     [:c_return,20, "xyzzy", Kernel,      :raise,           self,        nil, nil],
     [:c_call,  20, "xyzzy", Exception,   :backtrace,       raised_exc,  nil, nil],
     [:c_return,20, "xyzzy", Exception,   :backtrace,       raised_exc,  nil, nil],
     [:raise,   20, "xyzzy", TestSetTraceFunc, :trace_by_tracepoint, self, :outer, raised_exc],
     [:c_call,  20, "xyzzy", Module,      :===,             RuntimeError, nil, nil],
     [:c_return,20, "xyzzy", Module,      :===,             RuntimeError, nil, nil],
     [:line,    21, "xyzzy", TestSetTraceFunc, method,      self,        :outer, :nothing],
     [:c_call,  21, "xyzzy", TracePoint,  :disable,         trace,       nil, nil],
     ]
    return events, answer_events
  end

  def test_set_trace_func_curry_argument_error
    b = lambda {|x, y, z| (x||0) + (y||0) + (z||0) }.curry[1, 2]
    set_trace_func(proc {})
    assert_raise(ArgumentError) {b[3, 4]}
  end

  def test_set_trace_func
    actual_events, expected_events = trace_by_set_trace_func
    expected_events.zip(actual_events){|e, a|
      a[0] = a[0].to_s.sub('-', '_').to_sym
      assert_equal e[0..2], a[0..2], a.inspect

      # event, line, file, klass, id, binding.eval('self'), binding.eval("_local_var")
      assert_equal e[3].nil?, a[3].nil? # klass
      assert_equal e[4].nil?, a[4].nil? # id
      assert_equal e[6], a[6]           # _local_var
    }
  end

  def test_tracepoint_object_id
    tps = []
    trace = TracePoint.trace(){|tp|
      next if !target_thread?
      tps << tp
    }
    tap{}
    tap{}
    tap{}
    trace.disable

    # passed tp is unique, `trace' object which is generated by TracePoint.trace
    tps.each{|tp|
      assert_equal trace, tp
    }
  end

  def test_tracepoint_access_from_outside
    tp_store = nil
    trace = TracePoint.trace(){|tp|
      next if !target_thread?
      tp_store = tp
    }
    tap{}
    trace.disable

    assert_raise(RuntimeError){tp_store.lineno}
    assert_raise(RuntimeError){tp_store.event}
    assert_raise(RuntimeError){tp_store.path}
    assert_raise(RuntimeError){tp_store.method_id}
    assert_raise(RuntimeError){tp_store.defined_class}
    assert_raise(RuntimeError){tp_store.binding}
    assert_raise(RuntimeError){tp_store.self}
    assert_raise(RuntimeError){tp_store.return_value}
    assert_raise(RuntimeError){tp_store.raised_exception}
  end

  def foo
  end

  def test_tracepoint_enable
    ary = []
    args = nil
    begin
      trace = TracePoint.new(:call){|tp|
        next if !target_thread?
        ary << tp.method_id
      }
      foo
      trace.enable(target_thread: nil){|*a|
        args = a
        foo
      }
      foo
      assert_equal([:foo], ary)
      assert_equal([], args)
    ensure
      trace&.disable
    end

    trace = TracePoint.new{}
    begin
      assert_equal(false, trace.enable)
      assert_equal(true, trace.enable)
      trace.enable(target_thread: nil){}
      trace.disable
      assert_equal(false, trace.enable)
    ensure
      trace.disable
    end
  end

  def test_tracepoint_disable
    ary = []
    args = nil
    trace = TracePoint.trace(:call){|tp|
      next if !target_thread?
      # In parallel testing, unexpected events like IO operations may be traced,
      # so we filter out events here.
      next unless [TracePoint, TestSetTraceFunc].include?(tp.defined_class)
      ary << tp.method_id
    }
    foo
    trace.disable{|*a|
      args = a
      foo
    }
    foo
    trace.disable
    assert_equal([:foo, :disable, :foo, :disable], ary)
    assert_equal([], args)

    trace = TracePoint.new{}
    trace.enable{
      assert_equal(true, trace.disable)
      assert_equal(false, trace.disable)
      trace.disable{}
      assert_equal(false, trace.disable)
    }
  end

  def test_tracepoint_enabled
    trace = TracePoint.trace(:call){|tp|
      #
    }
    assert_equal(true, trace.enabled?)
    trace.disable{
      assert_equal(false, trace.enabled?)
      trace.enable{
        assert_equal(true, trace.enabled?)
      }
    }
    trace.disable
    assert_equal(false, trace.enabled?)
  end

  def parameter_test(a, b, c)
    yield
  end

  def test_tracepoint_parameters
    trace = TracePoint.new(:line, :class, :end, :call, :return, :b_call, :b_return, :c_call, :c_return, :raise){|tp|
      next if !target_thread?
      next if tp.path != __FILE__
      case tp.event
      when :call, :return
        assert_equal([[:req, :a], [:req, :b], [:req, :c]], tp.parameters)
      when :b_call, :b_return
        next if tp.parameters == []
        if tp.parameters.first == [:opt, :x]
          assert_equal([[:opt, :x], [:opt, :y], [:opt, :z]], tp.parameters)
        else
          assert_equal([[:req, :p], [:req, :q], [:req, :r]], tp.parameters)
        end
      when :c_call, :c_return
        assert_equal([[:req]], tp.parameters) if tp.method_id == :getbyte
      when :line, :class, :end, :raise
        assert_raise(RuntimeError) { tp.parameters }
      end
    }
    obj = Object.new
    trace.enable{
      parameter_test(1, 2, 3) {|x, y, z|
      }
      lambda {|p, q, r| }.call(4, 5, 6)
      "".getbyte(0)
      class << obj
      end
      begin
        raise
      rescue
      end
    }
  end

  def method_test_tracepoint_return_value obj
    obj
  end

  def test_tracepoint_return_value
    trace = TracePoint.new(:call, :return){|tp|
      next if !target_thread?
      next if tp.path != __FILE__
      case tp.event
      when :call
        assert_raise(RuntimeError) {tp.return_value}
      when :return
        assert_equal("xyzzy", tp.return_value)
      end
    }
    trace.enable{
      method_test_tracepoint_return_value "xyzzy"
    }
  end

  def test_tracepoint_attr
    c = Class.new do
      attr_accessor :x
      alias y x
      alias y= x=
    end
    obj = c.new

    ar_meth = obj.method(:x)
    aw_meth = obj.method(:x=)
    aar_meth = obj.method(:y)
    aaw_meth = obj.method(:y=)
    events = []
    trace = TracePoint.new(:c_call, :c_return){|tp|
      next if !target_thread?
      next if tp.path != __FILE__
      next if tp.method_id == :call
      case tp.event
      when :c_call
        assert_raise(RuntimeError) {tp.return_value}
        events << [tp.event, tp.method_id, tp.callee_id]
      when :c_return
        events << [tp.event, tp.method_id, tp.callee_id, tp.return_value]
      end
    }
    test_proc = proc do
      obj.x = 1
      obj.x
      obj.y = 2
      obj.y
      aw_meth.call(1)
      ar_meth.call
      aaw_meth.call(2)
      aar_meth.call
    end
    test_proc.call # populate call caches
    trace.enable(&test_proc)
    expected = [
      [:c_call, :x=, :x=],
      [:c_return, :x=, :x=, 1],
      [:c_call, :x, :x],
      [:c_return, :x, :x, 1],
      [:c_call, :x=, :y=],
      [:c_return, :x=, :y=, 2],
      [:c_call, :x, :y],
      [:c_return, :x, :y, 2],
    ]
    assert_equal(expected*2, events)
  end

  def test_tracepoint_struct
    c = Struct.new(:x) do
      alias y x
      alias y= x=
    end
    obj = c.new

    ar_meth = obj.method(:x)
    aw_meth = obj.method(:x=)
    aar_meth = obj.method(:y)
    aaw_meth = obj.method(:y=)
    events = []
    trace = TracePoint.new(:c_call, :c_return){|tp|
      next if !target_thread?
      next if tp.path != __FILE__
      next if tp.method_id == :call
      case tp.event
      when :c_call
        assert_raise(RuntimeError) {tp.return_value}
        events << [tp.event, tp.method_id, tp.callee_id]
      when :c_return
        events << [tp.event, tp.method_id, tp.callee_id, tp.return_value]
      end
    }
    test_proc = proc do
      obj.x = 1
      obj.x
      obj.y = 2
      obj.y
      aw_meth.call(1)
      ar_meth.call
      aaw_meth.call(2)
      aar_meth.call
    end
    test_proc.call # populate call caches
    trace.enable(&test_proc)
    expected = [
      [:c_call, :x=, :x=],
      [:c_return, :x=, :x=, 1],
      [:c_call, :x, :x],
      [:c_return, :x, :x, 1],
      [:c_call, :x=, :y=],
      [:c_return, :x=, :y=, 2],
      [:c_call, :x, :y],
      [:c_return, :x, :y, 2],
    ]
    assert_equal(expected*2, events)
  end

  class XYZZYException < Exception; end
  def method_test_tracepoint_raised_exception err
    raise err
  end

  def test_tracepoint_raised_exception
    trace = TracePoint.new(:call, :return, :raise){|tp|
      next if !target_thread?
      case tp.event
      when :call, :return
        assert_raise(RuntimeError) { tp.raised_exception }
      when :raise
        assert_kind_of(XYZZYException, tp.raised_exception)
      end
    }
    trace.enable{
      begin
        method_test_tracepoint_raised_exception XYZZYException
      rescue XYZZYException
        # ok
      else
        raise
      end
    }
  end

  def method_for_test_tracepoint_block
    yield
  end

  def test_tracepoint_block
    events = []
    TracePoint.new(:call, :return, :c_call, :b_call, :c_return, :b_return){|tp|
      next if !target_thread?
      events << [
        tp.event, tp.method_id, tp.defined_class, tp.self.class,
        /return/ =~ tp.event ? tp.return_value : nil
      ]
    }.enable{
      [1].map!{
        3
      }
      method_for_test_tracepoint_block{
        4
      }
    }
    # pp events
    # expected_events =
    [[:b_call, :test_tracepoint_block, TestSetTraceFunc, TestSetTraceFunc, nil],
     [:c_call, :map!, Array, Array, nil],
     [:b_call, :test_tracepoint_block, TestSetTraceFunc, TestSetTraceFunc, nil],
     [:b_return, :test_tracepoint_block, TestSetTraceFunc, TestSetTraceFunc, 3],
     [:c_return, :map!, Array, Array, [3]],
     [:call, :method_for_test_tracepoint_block, TestSetTraceFunc, TestSetTraceFunc, nil],
     [:b_call, :test_tracepoint_block, TestSetTraceFunc, TestSetTraceFunc, nil],
     [:b_return, :test_tracepoint_block, TestSetTraceFunc, TestSetTraceFunc, 4],
     [:return, :method_for_test_tracepoint_block, TestSetTraceFunc, TestSetTraceFunc, 4],
     [:b_return, :test_tracepoint_block, TestSetTraceFunc, TestSetTraceFunc, 4]
    ].zip(events){|expected, actual|
      assert_equal(expected, actual)
    }
  end

  def test_tracepoint_thread
    events = []
    thread_self = nil
    created_thread = nil
    TracePoint.new(:thread_begin, :thread_end){|tp|
      events << [Thread.current,
                 tp.event,
                 tp.lineno,  #=> 0
                 tp.path,    #=> nil
                 tp.binding, #=> nil
                 tp.defined_class, #=> nil,
                 tp.self.class # tp.self return creating/ending thread
                 ]
    }.enable(target_thread: nil){
      created_thread = Thread.new{thread_self = self}
      created_thread.join
    }
    events.reject!{|i| i[0] != created_thread}
    assert_equal(self, thread_self)
    assert_equal([created_thread, :thread_begin, 0, nil, nil, nil, Thread], events[0])
    assert_equal([created_thread, :thread_end, 0, nil, nil, nil, Thread], events[1])
    assert_equal(2, events.size)
  end

  def test_tracepoint_inspect
    events = []
    th = nil
    trace = TracePoint.new{|tp|
      next if !target_thread? && th != Thread.current
      events << [tp.event, tp.inspect]
    }
    assert_equal("#<TracePoint:disabled>", trace.inspect)
    trace.enable{
      assert_equal("#<TracePoint:enabled>", trace.inspect)
      th = Thread.new{}
      th.join
    }
    assert_equal("#<TracePoint:disabled>", trace.inspect)
    events.each{|(ev, str)|
      case ev
      when :line
        assert_match(/ in /, str)
      when :call, :c_call
        assert_match(/call \'/, str) # #<TracePoint:c_call 'inherited' ../trunk/test.rb:11>
      when :return, :c_return
        assert_match(/return \'/, str) # #<TracePoint:return 'm' ../trunk/test.rb:3>
      when /thread/
        assert_match(/\#<Thread:/, str) # #<TracePoint:thread_end of #<Thread:0x87076c0>>
      else
        assert_match(/\#<TracePoint:/, str)
      end
    }
  end

  def test_tracepoint_exception_at_line
    assert_raise(RuntimeError) do
      TracePoint.new(:line) {
        next if !target_thread?
        raise
      }.enable {
        1
      }
    end
  end

  def test_tracepoint_exception_at_return
    assert_nothing_raised(Timeout::Error, 'infinite trace') do
      assert_normal_exit('def m; end; TracePoint.new(:return) {raise}.enable {m}', '', timeout: 3)
    end
  end

  def test_tracepoint_exception_at_c_return
    assert_nothing_raised(Timeout::Error, 'infinite trace') do
      assert_normal_exit %q{
        begin
          TracePoint.new(:c_return){|tp|
            raise
          }.enable{
            tap{ itself }
          }
        rescue
        end
      }, '', timeout: 3
    end
  end

  def test_tracepoint_with_multithreads
    assert_nothing_raised do
      TracePoint.new(:line){
        10.times{
          Thread.pass
        }
      }.enable do
        (1..10).map{
          Thread.new{
            1_000.times{|i|
              _a = i
            }
          }
        }.each{|th|
          th.join
        }
      end
      _a = 1
      _b = 2
      _c = 3 # to make sure the deletion of unused TracePoints
    end
  end

  class FOO_ERROR < RuntimeError; end
  class BAR_ERROR < RuntimeError; end
  def m1_test_trace_point_at_return_when_exception
    m2_test_trace_point_at_return_when_exception
  end
  def m2_test_trace_point_at_return_when_exception
    raise BAR_ERROR
  end

  def test_trace_point_at_return_when_exception
    bug_7624 = '[ruby-core:51128] [ruby-trunk - Bug #7624]'
    TracePoint.new{|tp|
      next if !target_thread?
      if tp.event == :return &&
        tp.method_id == :m2_test_trace_point_at_return_when_exception
        raise FOO_ERROR
      end
    }.enable do
      assert_raise(FOO_ERROR, bug_7624) do
        m1_test_trace_point_at_return_when_exception
      end
    end

    bug_7668 = '[Bug #7668]'
    ary = []
    trace = TracePoint.new{|tp|
      next if !target_thread?
      ary << tp.event
      raise
    }
    begin
      trace.enable{
        1.times{
          raise
        }
      }
    rescue
      assert_equal([:b_call, :b_return], ary, bug_7668)
    end
  end

  def m1_for_test_trace_point_binding_in_ifunc(arg)
    arg + nil
  rescue
  end

  def m2_for_test_trace_point_binding_in_ifunc(arg)
    arg.inject(:+)
  rescue
  end

  def test_trace_point_binding_in_ifunc
    bug7774 = '[ruby-dev:46908]'
    src = %q{
      tp = TracePoint.new(:raise) do |tp|
        tp.binding
      end
      tp.enable do
        obj = Object.new
        class << obj
          include Enumerable
          def each
            yield 1
          end
        end
        %s
      end
    }
    assert_normal_exit src % %q{obj.zip({}) {}}, bug7774
    if respond_to?(:callcc)
      assert_normal_exit src % %q{
        require 'continuation'
        begin
          c = nil
          obj.sort_by {|x| callcc {|c2| c ||= c2 }; x }
          c.call
        rescue RuntimeError
        end
      }, bug7774
    end

    # TracePoint
    tp_b = nil
    TracePoint.new(:raise) do |tp|
      next if !target_thread?
      tp_b = tp.binding
    end.enable do
      m1_for_test_trace_point_binding_in_ifunc(0)
      assert_equal(self, eval('self', tp_b), '[ruby-dev:46960]')

      m2_for_test_trace_point_binding_in_ifunc([0, nil])
      assert_equal(self, eval('self', tp_b), '[ruby-dev:46960]')
    end

    # set_trace_func
    stf_b = nil
    set_trace_func ->(event, file, line, id, binding, klass) do
      stf_b = binding if event == 'raise'
    end
    begin
      m1_for_test_trace_point_binding_in_ifunc(0)
      assert_equal(self, eval('self', stf_b), '[ruby-dev:46960]')

      m2_for_test_trace_point_binding_in_ifunc([0, nil])
      assert_equal(self, eval('self', stf_b), '[ruby-dev:46960]')
    ensure
      set_trace_func(nil)
    end
  end

  def test_trace_point_binding_after_break
    bug10689 = '[ruby-dev:48797]'
    assert_in_out_err([], <<-INPUT, [], [], bug10689)
      class Bug
        include Enumerable

        def each
          [0].each do
            yield
          end
        end
      end

      TracePoint.trace(:c_return) do |tp|
        tp.binding
      end

      Bug.new.all? { false }
    INPUT
  end

  def test_tracepoint_b_return_with_next
    n = 0
    TracePoint.new(:b_return){
      next if !target_thread?
      n += 1
    }.enable{
      3.times{
        next
      } # 3 times b_return
    }   # 1 time b_return

    assert_equal 4, n
  end

  def test_tracepoint_b_return_with_lambda
    n = 0
    TracePoint.new(:b_return){
      next if !target_thread?
      n+=1
    }.enable{
      lambda{
        return
      }.call     # n += 1 #=> 1
      3.times{
        lambda{
          return # n += 3 #=> 4
        }.call
      }          # n += 3 #=> 7
      begin
        lambda{
          raise
        }.call   # n += 1 #=> 8
      rescue
        # ignore
      end        # n += 1 #=> 9
    }

    assert_equal 9, n
  end

  def test_isolated_raise_in_trace
    bug9088 = '[ruby-dev:47793] [Bug #9088]'
    assert_in_out_err([], <<-END, [], [], bug9088)
    set_trace_func proc {raise rescue nil}
    1.times {break}
    END
  end

  def test_a_call
    events = []
    log = []
    TracePoint.new(:a_call){|tp|
      next if !target_thread?
      events << tp.event
      log << "| event:#{ tp.event } method_id:#{ tp.method_id } #{ tp.path }:#{ tp.lineno }"
    }.enable{
      [1].map!{
        3
      }
      method_for_test_tracepoint_block{
        4
      }
    }
    assert_equal([
      :b_call,
      :c_call,
      :b_call,
      :call,
      :b_call,
    ], events, "TracePoint log:\n#{ log.join("\n") }\n")
  end

  def test_a_return
    events = []
    log = []
    TracePoint.new(:a_return){|tp|
      next if !target_thread?
      events << tp.event
      log << "| event:#{ tp.event } method_id:#{ tp.method_id } #{ tp.path }:#{ tp.lineno }"
    }.enable{
      [1].map!{
        3
      }
      method_for_test_tracepoint_block{
        4
      }
    }
    assert_equal([
      :b_return,
      :c_return,
      :b_return,
      :return,
      :b_return
    ], events, "TracePoint log:\n#{ log.join("\n") }\n")
  end

  def test_const_missing
    bug59398 = '[ruby-core:59398]'
    events = []
    assert !defined?(MISSING_CONSTANT_59398)
    TracePoint.new(:c_call, :c_return, :call, :return){|tp|
      next if !target_thread?
      next unless tp.defined_class == Module
      # rake/ext/module.rb aliases :const_missing and Ruby uses the aliased name
      # but this only happens when running the full test suite
      events << [tp.event,tp.method_id] if tp.method_id == :const_missing || tp.method_id == :rake_original_const_missing
    }.enable{
      MISSING_CONSTANT_59398 rescue nil
    }
    if events.map{|e|e[1]}.include?(:rake_original_const_missing)
      assert_equal([
        [:call, :const_missing],
        [:c_call, :rake_original_const_missing],
        [:c_return, :rake_original_const_missing],
        [:return, :const_missing],
      ], events, bug59398)
    else
      assert_equal([
        [:c_call, :const_missing],
        [:c_return, :const_missing]
      ], events, bug59398)
    end
  end

  class AliasedRubyMethod
    def foo; 1; end;
    alias bar foo
  end
  def test_aliased_ruby_method
    events = []
    aliased = AliasedRubyMethod.new
    TracePoint.new(:call, :return){|tp|
      next if !target_thread?
      events << [tp.event, tp.method_id]
    }.enable{
      aliased.bar
    }
    assert_equal([
      [:call, :foo],
      [:return, :foo]
    ], events, "should use original method name for tracing ruby methods")
  end
  class AliasedCMethod < Hash
    alias original_size size
    def size; original_size; end
  end

  def test_aliased_c_method
    events = []
    aliased = AliasedCMethod.new
    TracePoint.new(:call, :return, :c_call, :c_return){|tp|
      next if !target_thread?
      events << [tp.event, tp.method_id]
    }.enable{
      aliased.size
    }
    assert_equal([
      [:call, :size],
      [:c_call, :size],
      [:c_return, :size],
      [:return, :size]
    ], events, "should use alias method name for tracing c methods")
  end

  def test_method_missing
    bug59398 = '[ruby-core:59398]'
    events = []
    assert !respond_to?(:missing_method_59398)
    TracePoint.new(:c_call, :c_return, :call, :return){|tp|
      next if !target_thread?
      next unless tp.defined_class == BasicObject
      # rake/ext/module.rb aliases :const_missing and Ruby uses the aliased name
      # but this only happens when running the full test suite
      events << [tp.event,tp.method_id] if tp.method_id == :method_missing
    }.enable{
      missing_method_59398 rescue nil
    }
    assert_equal([
      [:c_call, :method_missing],
      [:c_return, :method_missing]
    ], events, bug59398)
  end

  class C9759
    define_method(:foo){
      raise
    }
  end

  def test_define_method_on_exception
    events = []
    obj = C9759.new
    TracePoint.new(:call, :return){|tp|
      next unless target_thread?
      events << [tp.event, tp.method_id]
    }.enable{
      obj.foo rescue nil
    }
    assert_equal([[:call, :foo], [:return, :foo]], events, 'Bug #9759')

    events = []
    begin
      set_trace_func(lambda{|event, file, lineno, mid, binding, klass|
        next unless target_thread?
        case event
        when 'call', 'return'
          events << [event, mid]
        end
      })
      obj.foo rescue nil
      set_trace_func(nil)

      assert_equal([['call', :foo], ['return', :foo]], events, 'Bug #9759')
    ensure
    end
  end

  class C11492
    define_method(:foo_return){
      return true
    }
    define_method(:foo_break){
      break true
    }
  end

  def test_define_method_on_return
    # return
    events = []
    obj = C11492.new
    TracePoint.new(:call, :return){|tp|
      next unless target_thread?
      events << [tp.event, tp.method_id]
    }.enable{
      obj.foo_return
    }
    assert_equal([[:call, :foo_return], [:return, :foo_return]], events, 'Bug #11492')

    # break
    events = []
    obj = C11492.new
    TracePoint.new(:call, :return){|tp|
      next unless target_thread?
      events << [tp.event, tp.method_id]
    }.enable{
      obj.foo_break
    }
    assert_equal([[:call, :foo_break], [:return, :foo_break]], events, 'Bug #11492')

    # set_trace_func
    # return
    events = []
    begin
      set_trace_func(lambda{|event, file, lineno, mid, binding, klass|
        next unless target_thread?
        case event
        when 'call', 'return'
          events << [event, mid]
        end
      })
      obj.foo_return
      set_trace_func(nil)

      assert_equal([['call', :foo_return], ['return', :foo_return]], events, 'Bug #11492')
    ensure
    end

    # break
    events = []
    begin
      set_trace_func(lambda{|event, file, lineno, mid, binding, klass|
        next unless target_thread?
        case event
        when 'call', 'return'
          events << [event, mid]
        end
      })
      obj.foo_break
      set_trace_func(nil)

      assert_equal([['call', :foo_break], ['return', :foo_break]], events, 'Bug #11492')
    ensure
    end
  end

  def test_recursive
    assert_in_out_err([], %q{\
      TracePoint.new(:c_call){|tp|
        p tp.method_id
      }.enable{
        p 1
      }
    }, %w[:p :to_s 1], [], '[Bug #9940]')
  end

  def method_prefix event
    case event
    when :call, :return
      :n
    when :c_call, :c_return
      :c
    when :b_call, :b_return
      :b
    end
  end

  def method_label tp
    "#{method_prefix(tp.event)}##{tp.method_id}"
  end

  def assert_consistent_call_return message='', check_events: nil
    check_events ||= %i(a_call a_return)
    call_stack = []

    TracePoint.new(*check_events){|tp|
      next unless target_thread?

      case tp.event.to_s
      when /call/
        call_stack << method_label(tp)
      when /return/
        frame = call_stack.pop
        assert_equal(frame, method_label(tp))
      end
    }.enable do
      yield
    end

    assert_equal true, call_stack.empty?
  end

  def method_test_rescue_should_not_cause_b_return
    begin
      raise
    rescue
      return
    end
  end

  def method_test_ensure_should_not_cause_b_return
    begin
      raise
    ensure
      return
    end
  end

  def test_rescue_and_ensure_should_not_cause_b_return
    assert_consistent_call_return '[Bug #9957]' do
      method_test_rescue_should_not_cause_b_return
      begin
        method_test_ensure_should_not_cause_b_return
      rescue
        # ignore
      end
    end
  end

  define_method(:method_test_argument_error_on_bmethod){|correct_key: 1|}

  def test_argument_error_on_bmethod
    assert_consistent_call_return '[Bug #9959]' do
      begin
        method_test_argument_error_on_bmethod(wrong_key: 2)
      rescue
        # ignore
      end
    end
  end

  def test_rb_rescue
    assert_consistent_call_return '[Bug #9961]' do
      begin
        -Numeric.new
      rescue
        # ignore
      end
    end
  end

  def test_b_call_with_redo
    assert_consistent_call_return '[Bug #9964]' do
      i = 0
      1.times{
        break if (i+=1) > 10
        redo
      }
    end
  end

  def test_no_duplicate_line_events
    lines = []
    dummy = []

    TracePoint.new(:line){|tp|
      next unless target_thread?
      lines << tp.lineno
    }.enable{
      dummy << (1) + (2)
      dummy << (1) + (2)
    }
    assert_equal [__LINE__ - 3, __LINE__ - 2], lines, 'Bug #10449'
  end

  def test_elsif_line_event
    bug10763 = '[ruby-core:67720] [Bug #10763]'
    lines = []
    line = nil

    TracePoint.new(:line){|tp|
      next unless target_thread?
      lines << tp.lineno if line
    }.enable{
      line = __LINE__
      if !line
        1
      elsif line
        2
      end
    }
    assert_equal [line+1, line+3, line+4], lines, bug10763
  end

  class Bug10724
    def initialize
      loop{return}
    end
  end

  def test_throwing_return_with_finish_frame
    evs = []

    TracePoint.new(:call, :return){|tp|
      next unless target_thread?
      evs << tp.event
    }.enable{
      Bug10724.new
    }

    assert_equal([:call, :call, :return, :return], evs)
  end

  require 'fiber'
  def test_fiber_switch
    # test for resume/yield
    evs = []
    TracePoint.new(:fiber_switch){|tp|
      next unless target_thread?
      evs << tp.event
    }.enable{
      f = Fiber.new{
        Fiber.yield
        Fiber.yield
        Fiber.yield
      }
      f.resume
      f.resume
      f.resume
      f.resume
      begin
        f.resume
      rescue FiberError
      end
    }
    assert_equal 8, evs.size
    evs.each{|ev|
      assert_equal ev, :fiber_switch
    }

    # test for raise into resumable fiber
    evs = []
    f = nil
    TracePoint.new(:raise, :fiber_switch){|tp|
      next unless target_thread?
      evs << [tp.event, Fiber.current]
    }.enable{
      f = Fiber.new{
        Fiber.yield # will raise
        Fiber.yield # unreachable
      }
      begin
        f.resume
        f.raise StopIteration
      rescue StopIteration
        evs << :rescued
      end
    }
    assert_equal [:fiber_switch, f],             evs[0], "initial resume"
    assert_equal [:fiber_switch, Fiber.current], evs[1], "Fiber.yield"
    assert_equal [:fiber_switch, f],             evs[2], "fiber.raise"
    assert_equal [:raise, f],                    evs[3], "fiber.raise"
    assert_equal [:fiber_switch, Fiber.current], evs[4], "terminated with raise"
    assert_equal [:raise, Fiber.current],        evs[5], "terminated with raise"
    assert_equal :rescued,                       evs[6]
    assert_equal 7, evs.size

    # test for transfer
    evs = []
    TracePoint.new(:fiber_switch){|tp|
      next unless target_thread?
      evs << tp.event
    }.enable{
      f1 = f2 = nil
      f1 = Fiber.new{
        f2.transfer
        f2.transfer
        Fiber.yield :ok
      }
      f2 = Fiber.new{
        f1.transfer
        f1.transfer
      }
      assert_equal :ok, f1.resume
    }
    assert_equal 6, evs.size
    evs.each{|ev|
      assert_equal ev, :fiber_switch
    }

    # test for raise and from transferring fibers
    evs = []
    f1 = f2 = nil
    TracePoint.new(:raise, :fiber_switch){|tp|
      next unless target_thread?
      evs << [tp.event, Fiber.current]
    }.enable{
      f1 = Fiber.new{
        f2.transfer
        f2.raise ScriptError
        Fiber.yield :ok
      }
      f2 = Fiber.new{
        f1.transfer
        f1.transfer
      }
      begin
        f1.resume
      rescue ScriptError
        evs << :rescued
      end
    }
    assert_equal [:fiber_switch, f1],            evs[0], "initial resume"
    assert_equal [:fiber_switch, f2],            evs[1], "f2.transfer"
    assert_equal [:fiber_switch, f1],            evs[2], "f1.transfer"
    assert_equal [:fiber_switch, f2],            evs[3], "f2.raise ScriptError"
    assert_equal [:raise,        f2],            evs[4], "f2.raise ScriptError"
    assert_equal [:fiber_switch, f1],            evs[5], "f2 unhandled exception"
    assert_equal [:raise,        f1],            evs[6], "f2 unhandled exception"
    assert_equal [:fiber_switch, Fiber.current], evs[7], "f1 unhandled exception"
    assert_equal [:raise,        Fiber.current], evs[8], "f1 unhandled exception"
    assert_equal :rescued,                       evs[9], "rescued everything"
    assert_equal 10, evs.size

  end

  def test_tracepoint_callee_id
    events = []
    capture_events = Proc.new{|tp|
      next unless target_thread?
      events << [tp.event, tp.method_id, tp.callee_id]
    }

    o = Class.new{
      def m
        raise
      end
      alias alias_m m
    }.new
    TracePoint.new(:raise, :call, :return, &capture_events).enable{
      o.alias_m rescue nil
    }
    assert_equal [[:call, :m, :alias_m], [:raise, :m, :alias_m], [:return, :m, :alias_m]], events
    events.clear

    o = Class.new{
      alias alias_raise raise
      def m
        alias_raise
      end
    }.new
    TracePoint.new(:c_return, &capture_events).enable{
      o.m rescue nil
    }
    assert_equal [:c_return, :raise, :alias_raise], events[0]
    events.clear

    o = Class.new(String){
      include Enumerable
      alias each each_char
    }.new('foo')
    TracePoint.new(:c_return, &capture_events).enable{
      o.find{true}
    }
    assert_equal [:c_return, :each_char, :each], events[0]
    events.clear

    o = Class.new{
      define_method(:m){}
      alias alias_m m
    }.new
    TracePoint.new(:call, :return, &capture_events).enable{
      o.alias_m
    }
    assert_equal [[:call, :m, :alias_m], [:return, :m, :alias_m]], events
    events.clear

    o = Class.new{
      def m
        tap{return}
      end
      alias alias_m m
    }.new
    TracePoint.new(:return, &capture_events).enable{
      o.alias_m
    }
    assert_equal [[:return, :tap, :tap], [:return, :m, :alias_m]], events
    events.clear

    o = Class.new{
      define_method(:m){raise}
      alias alias_m m
    }.new
    TracePoint.new(:b_return, :return, &capture_events).enable{
      o.alias_m rescue nil
    }
    assert_equal [[:b_return, :m, :alias_m], [:return, :m, :alias_m]], events[0..1]
    events.clear

    o = Class.new{
      define_method(:m){tap{return}}
      alias alias_m m
    }.new
    TracePoint.new(:b_return, &capture_events).enable{
      o.alias_m
    }
    assert_equal [[:b_return, :m, :alias_m], [:b_return, :m, :alias_m]], events[0..1]
    events.clear

    o = Class.new{
      alias alias_singleton_class singleton_class
      define_method(:m){alias_singleton_class}
    }.new
    TracePoint.new(:c_return, &capture_events).enable{
      o.m
    }
    assert_equal [[:c_return, :singleton_class, :alias_singleton_class]], events
    events.clear

    c = Class.new{
      alias initialize itself
    }
    TracePoint.new(:c_call, &capture_events).enable{
      c.new
    }
    assert_equal [:c_call, :itself, :initialize], events[1]
    events.clear

    o = Class.new{
      alias alias_itself itself
    }.new
    TracePoint.new(:c_call, :c_return, &capture_events).enable{
      o.alias_itself
    }
    assert_equal [[:c_call, :itself, :alias_itself], [:c_return, :itself, :alias_itself]], events
    events.clear
  end

  # tests for `return_value` with non-local exit [Bug #13369]

  def tp_return_value mid
    ary = []
    TracePoint.new(:return, :b_return){|tp|
      next if !target_thread?
      next if tp.path != __FILE__
      ary << [tp.event, tp.method_id, tp.return_value]
    }.enable{
      send mid
    }
    ary.pop # last b_return event is not required.
    ary
  end

  def test_single_raise_inside_load
    events = []
    tmpdir = Dir.mktmpdir
    path = "#{tmpdir}/hola.rb"
    File.open(path, "w") { |f| f.write("raise") }
    tp = TracePoint.new(:raise) {|tp| events << [tp.event] if target_thread?}
    tp.enable{
      load path rescue nil
    }
    assert_equal [[:raise]], events
    events.clear
    tp.enable{
      require path rescue nil
    }
    assert_equal [[:raise]], events
  ensure
    FileUtils.rmtree(tmpdir)
  end

  def f_raise
    raise
  rescue
    return :f_raise_return
  end

  def f_iter1
    yield
    return :f_iter1_return
  end

  def f_iter2
    yield
    return :f_iter2_return
  end

  def f_return_in_iter
    f_iter1 do
      f_iter2 do
        return :f_return_in_iter_return
      end
    end
    2
  end

  def f_break_in_iter
    f_iter1 do
      f_iter2 do
        break :f_break_in_iter_break
      end
      :f_iter1_block_value
    end
    :f_break_in_iter_return
  end

  def test_return_value_with_rescue
    assert_equal [[:return,   :f_raise,          :f_raise_return]],
                 tp_return_value(:f_raise),
                 '[Bug #13369]'

    assert_equal [[:b_return, :f_return_in_iter, nil],
                  [:return,   :f_iter2,          nil],
                  [:b_return, :f_return_in_iter, nil],
                  [:return,   :f_iter1,          nil],
                  [:return,   :f_return_in_iter, :f_return_in_iter_return]],
                 tp_return_value(:f_return_in_iter),
                 '[Bug #13369]'

    assert_equal [[:b_return, :f_break_in_iter,  :f_break_in_iter_break],
                  [:return,   :f_iter2,          nil],
                  [:b_return, :f_break_in_iter,  :f_iter1_block_value],
                  [:return,   :f_iter1,          :f_iter1_return],
                  [:return,   :f_break_in_iter,  :f_break_in_iter_return]],
                 tp_return_value(:f_break_in_iter),
                 '[Bug #13369]'
  end

  define_method(:f_last_defined) do
    :f_last_defined
  end

  define_method(:f_return_defined) do
    return :f_return_defined
  end

  define_method(:f_break_defined) do
    break :f_break_defined
  end

  define_method(:f_raise_defined) do
    raise
  rescue
    return :f_raise_defined
  end

  define_method(:f_break_in_rescue_defined) do
    raise
  rescue
    break :f_break_in_rescue_defined
  end

  def test_return_value_with_rescue_and_defined_methods
    assert_equal [[:b_return, :f_last_defined, :f_last_defined],
                  [:return,   :f_last_defined, :f_last_defined]],
                 tp_return_value(:f_last_defined),
                 '[Bug #13369]'

    assert_equal [[:b_return, :f_return_defined, :f_return_defined],
                  [:return,   :f_return_defined, :f_return_defined]],
                 tp_return_value(:f_return_defined),
                 '[Bug #13369]'

    assert_equal [[:b_return, :f_break_defined, :f_break_defined],
                  [:return,   :f_break_defined, :f_break_defined]],
                 tp_return_value(:f_break_defined),
                 '[Bug #13369]'

    assert_equal [[:b_return, :f_raise_defined, f_raise_defined],
                  [:return,   :f_raise_defined, f_raise_defined]],
                 tp_return_value(:f_raise_defined),
                 '[Bug #13369]'

    assert_equal [[:b_return, :f_break_in_rescue_defined, f_break_in_rescue_defined],
                  [:return,   :f_break_in_rescue_defined, f_break_in_rescue_defined]],
                 tp_return_value(:f_break_in_rescue_defined),
                 '[Bug #13369]'
  end

  define_method(:just_yield) do |&block|
    block.call
  end

  define_method(:unwind_multiple_bmethods) do
    just_yield { return :unwind_multiple_bmethods }
  end

  def test_non_local_return_across_multiple_define_methods
    assert_equal [[:b_return, :unwind_multiple_bmethods, nil],
                  [:b_return, :just_yield, nil],
                  [:return,   :just_yield, nil],
                  [:b_return, :unwind_multiple_bmethods, :unwind_multiple_bmethods],
                  [:return,   :unwind_multiple_bmethods, :unwind_multiple_bmethods]],
                 tp_return_value(:unwind_multiple_bmethods)
  end

  def f_iter
    yield
  end

  def f_break_in_rescue
    f_iter do
      begin
        raise
      rescue
        break :b
      end
    end
    :f_break_in_rescue_return_value
  end

  def test_break_with_rescue
    assert_equal [[:b_return, :f_break_in_rescue, :b],
                  [:return, :f_iter, nil],
                  [:return, :f_break_in_rescue, :f_break_in_rescue_return_value]],
                 tp_return_value(:f_break_in_rescue),
                 '[Bug #13369]'
  end

  def test_trace_point_raising_exception_in_bmethod_call
    bug13705 = '[ruby-dev:50162]'
    assert_normal_exit %q{
      define_method(:m) {}

      tp = TracePoint.new(:call) do
        raise ''
      end

      tap do
        tap do
          begin
            tp.enable
            m
          rescue
          end
        end
      end
    }, bug13705
  end

  def test_trace_point_require_block
    assert_raise(ArgumentError) { TracePoint.new(:return) }
  end

  def method_for_test_thread_add_trace_func

  end

  def test_thread_add_trace_func
    events = []
    base_line = __LINE__
    q = Thread::Queue.new
    t = Thread.new{
      Thread.current.add_trace_func proc{|ev, file, line, *args|
        events << [ev, line] if file == __FILE__
      } # do not stop trace. They will be stopped at Thread termination.
      q.push 1
      _x = 1
      method_for_test_thread_add_trace_func
      _y = 2
    }
    q.pop
    method_for_test_thread_add_trace_func
    t.join
    assert_equal ["c-return", base_line + 3], events[0]
    assert_equal ["line", base_line + 6],     events[1]
    assert_equal ["c-call", base_line + 6],   events[2]
    assert_equal ["c-return", base_line + 6], events[3]
    assert_equal ["line", base_line + 7],     events[4]
    assert_equal ["line", base_line + 8],     events[5]
    assert_equal ["call", base_line + -6],    events[6]
    assert_equal ["return", base_line + -4],  events[7]
    assert_equal ["line", base_line + 9],     events[8]
    assert_equal nil,                         events[9]

    # other thread
    events = []
    m2t_q = Thread::Queue.new

    t = Thread.new{
      Thread.current.abort_on_exception = true
      assert_equal 1, m2t_q.pop
      _x = 1
      method_for_test_thread_add_trace_func
      _y = 2
      Thread.current.set_trace_func(nil)
      method_for_test_thread_add_trace_func
    }
    # it is dirty hack. usually we shouldn't use such technique
    Thread.pass until t.status == 'sleep'

    t.add_trace_func proc{|ev, file, line, *args|
      if file == __FILE__
        events << [ev, line]
      end
    }

    method_for_test_thread_add_trace_func

    m2t_q.push 1
    t.join

    assert_equal ["line", base_line + 32],     events[0]
    assert_equal ["line", base_line + 33],     events[1]
    assert_equal ["call", base_line + -6],     events[2]
    assert_equal ["return", base_line + -4],   events[3]
    assert_equal ["line", base_line + 34],     events[4]
    assert_equal ["line", base_line + 35],     events[5]
    assert_equal ["c-call", base_line + 35],   events[6] # Thread.current
    assert_equal ["c-return", base_line + 35], events[7] # Thread.current
    assert_equal ["c-call", base_line + 35],   events[8] # Thread#set_trace_func
    assert_equal nil,                          events[9]
  end

  def test_lineno_in_optimized_insn
    assert_separately([], "#{<<~"begin;"}\n#{<<~'end;'}")
    begin;
      $loc = nil
      class String
        undef -@
        def -@
          $loc = caller_locations(1, 1)[0].lineno
        end
      end

      assert_predicate(-"", :frozen?)
      assert_equal(__LINE__-1, $loc, '[Bug #14809]')
    end;
  end

  def method_for_enable_target1
    a = 1
    b = 2
    1.times{|i|
      _x = i
    }
    _c = a + b
  end

  def method_for_enable_target2
    a = 1
    b = 2
    1.times{|i|
      _x = i
    }
    _c = a + b
  end

  def check_with_events(trace_point_events, expected_events = trace_point_events)
    all_events = [[:call, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:b_call, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:b_return, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:return, :method_for_enable_target1],
                  # repeat
                  [:call, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:b_call, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:b_return, :method_for_enable_target1],
                  [:line, :method_for_enable_target1],
                  [:return, :method_for_enable_target1],
                 ]
    events = []
    TracePoint.new(*trace_point_events) do |tp|
      next unless target_thread?
      events << [tp.event, tp.method_id]
    end.enable(target: method(:method_for_enable_target1)) do
      method_for_enable_target1
      method_for_enable_target2
      method_for_enable_target1
    end

    assert_equal all_events.keep_if { |(ev)| expected_events.include? ev }, events
  end

  def test_tracepoint_enable_target
    check_with_events([:line])
    check_with_events([:call, :return])
    check_with_events([:line, :call, :return])
    check_with_events([:call, :return, :b_call, :b_return])
    check_with_events([:line, :call, :return, :b_call, :b_return])

    # No arguments passed into TracePoint.new enables all ISEQ_TRACE_EVENTS
    check_with_events([], [:line, :class, :end, :call, :return, :c_call, :c_return, :b_call, :b_return, :rescue])

    # Raise event should be ignored
    check_with_events([:line, :raise])
  end

  def test_tracepoint_nested_enabled_with_target
    code1 = proc{
      _a = 1
    }
    code2 = proc{
      _b = 2
    }

    ## error

    # targeted TP and targeted TP
    ex = assert_raise(ArgumentError) do
      tp = TracePoint.new(:line){}
      tp.enable(target: code1){
        tp.enable(target: code2){}
      }
    end
    assert_equal "can't nest-enable a targeting TracePoint", ex.message

    # global TP and targeted TP
    ex = assert_raise(ArgumentError) do
      tp = TracePoint.new(:line){}
      tp.enable(target_thread: nil){
        tp.enable(target: code2){}
      }
    end
    assert_equal "can't nest-enable a targeting TracePoint", ex.message

    # targeted TP and global TP
    ex = assert_raise(ArgumentError) do
      tp = TracePoint.new(:line){}
      tp.enable(target: code1){
        tp.enable{}
      }
    end
    assert_equal "can't nest-enable a targeting TracePoint", ex.message

    # targeted TP and disable
    ex = assert_raise(ArgumentError) do
      tp = TracePoint.new(:line){}
      tp.enable(target: code1){
        tp.disable{}
      }
    end
    assert_equal "can't disable a targeting TracePoint in a block", ex.message

    ## success with two nesting targeting tracepoints
    events = []
    tp1 = TracePoint.new(:line){|tp| events << :tp1}
    tp2 = TracePoint.new(:line){|tp| events << :tp2}
    tp1.enable(target: code1) do
      tp2.enable(target: code1) do
        code1.call
        events << :___
      end
    end
    assert_equal [:tp2, :tp1, :___], events

    # success with two tracepoints (global/targeting)
    events = []
    tp1 = TracePoint.new(:line){|tp| events << :tp1}
    tp2 = TracePoint.new(:line){|tp| events << :tp2}
    tp1.enable do
      tp2.enable(target: code1) do
        code1.call
        events << :___
      end
    end
    assert_equal [:tp1, :tp1, :tp1, :tp1, :tp2, :tp1, :___], events

    # success with two tracepoints (targeting/global)
    events = []
    tp1 = TracePoint.new(:line){|tp| events << :tp1}
    tp2 = TracePoint.new(:line){|tp| events << :tp2}
    tp1.enable(target: code1) do
      tp2.enable do
        code1.call
        events << :___
      end
    end
    assert_equal [:tp2, :tp2, :tp1, :tp2, :___], events
  end

  def test_tracepoint_enable_with_target_line
    events = []
    line_0 = __LINE__
    code1 = proc{
      events << 1
      events << 2
      events << 3
    }
    tp = TracePoint.new(:line) do |tp|
      events << :tp
    end
    tp.enable(target: code1, target_line: line_0 + 3) do
      code1.call
    end
    assert_equal [1, :tp, 2, 3], events


    e = assert_raise(ArgumentError) do
      TracePoint.new(:line){}.enable(target_line: 10){}
    end
    assert_equal 'only target_line is specified', e.message

    e = assert_raise(ArgumentError) do
      TracePoint.new(:call){}.enable(target: code1, target_line: 10){}
    end
    assert_equal 'target_line is specified, but line event is not specified', e.message
  end

  def test_tracepoint_enable_with_target_line_two_times
    events = []
    line_0 = __LINE__
    code1 = proc{
      events << 1 # tp1
      events << 2
      events << 3 # tp2
    }

    tp1 = TracePoint.new(:line) do |tp|
      events << :tp1
    end
    tp2 = TracePoint.new(:line) do |tp|
      events << :tp2
    end

    tp1.enable(target: code1, target_line: line_0 + 2) do
      tp2.enable(target: code1, target_line: line_0 + 4) do
        # two hooks
        code1.call
      end
    end
    assert_equal [:tp1, 1, 2, :tp2, 3], events
  end

  def test_multiple_enable
    ary = []
    trace = TracePoint.new(:call) do |tp|
      ary << tp.method_id
    end
    trace.enable
    trace.enable
    foo
    trace.disable
    assert_equal(1, ary.count(:foo), '[Bug #19114]')
  end

  def test_multiple_tracepoints_same_bmethod
    events = []
    tp1 = TracePoint.new(:return) do |tp|
      events << :tp1
    end
    tp2 = TracePoint.new(:return) do |tp|
      events << :tp2
    end

    obj = Object.new
    obj.define_singleton_method(:foo) {}
    bmethod = obj.method(:foo)

    tp1.enable(target: bmethod) do
      tp2.enable(target: bmethod) do
        obj.foo
      end
    end

    assert_equal([:tp2, :tp1], events, '[Bug #18031]')
  end

  def test_script_compiled
    events = []
    tp = TracePoint.new(:script_compiled){|tp|
      next unless target_thread?
      events << [tp.instruction_sequence.path,
                 tp.eval_script]
    }

    eval_script = 'a = 1'
    tp.enable{
      eval(eval_script, nil, __FILE__+"/eval")
      nil.instance_eval(eval_script, __FILE__+"/instance_eval")
      Object.class_eval(eval_script, __FILE__+"/class_eval")
    }
    assert_equal [[__FILE__+"/eval", eval_script],
                  [__FILE__+"/instance_eval", eval_script],
                  [__FILE__+"/class_eval", eval_script],
                 ], events

    events.clear
    tp.enable{
      begin
        eval('a=')
      rescue SyntaxError
      end
    }
    assert_equal [], events, 'script_compiled event should not be invoked on compile error'

    omit "TODO: test for requires"

    events.clear
    tp.enable{
      require ''
      require_relative ''
      load ''
    }
    assert_equal [], events
  end

  def test_enable_target_thread
    events = []
    TracePoint.new(:line) do |tp|
      events << Thread.current
    end.enable(target_thread: Thread.current) do
      _a = 1
      Thread.new{
        _b = 2
        _c = 3
      }.join
      _d = 4
    end
    assert_equal Array.new(3){Thread.current}, events

    events = []
    tp = TracePoint.new(:line) do |tp|
      events << Thread.current
    end

    q1 = Thread::Queue.new
    q2 = Thread::Queue.new

    th = Thread.new{
      q1 << :ok; q2.pop
      _t1 = 1
      _t2 = 2
    }
    q1.pop
    tp.enable(target_thread: th) do
      q2 << 1
      _a = 1
      _b = 2
      th.join
    end

    assert_equal Array.new(2){th}, events
  end

  def test_return_bmethod_location
    bug13392 = "[ruby-core:80515] incorrect bmethod return location"
    actual = nil
    obj = Object.new
    expected = __LINE__ + 1
    obj.define_singleton_method(:t){}
    tp = TracePoint.new(:return) do
      next unless target_thread?
      actual = tp.lineno
    end
    tp.enable {obj.t}
    assert_equal(expected, actual, bug13392)
  end

  def test_b_tracepoints_going_away
    # test that call and return TracePoints continue to work
    # when b_call and b_return TracePoints stop
    events = []
    record_events = ->(tp) do
      next unless target_thread?
      events << [tp.event, tp.method_id]
    end

    call_ret_tp = TracePoint.new(:call, :return, &record_events)
    block_call_ret_tp = TracePoint.new(:b_call, :b_return, &record_events)

    obj = Object.new
    obj.define_singleton_method(:foo) {} # a bmethod

    foo = obj.method(:foo)
    call_ret_tp.enable(target: foo) do
      block_call_ret_tp.enable(target: foo) do
        obj.foo
      end
      obj.foo
    end

    assert_equal(
      [
        [:call,     :foo],
        [:b_call,   :foo],
        [:b_return, :foo],
        [:return,   :foo],
        [:call,     :foo],
        [:return,   :foo],
      ],
      events,
    )
  end

  def test_target_different_bmethod_same_iseq
    # make two bmethods that share the same block iseq
    block = Proc.new {}
    obj = Object.new
    obj.define_singleton_method(:one, &block)
    obj.define_singleton_method(:two, &block)

    events = []
    record_events = ->(tp) do
      next unless target_thread?
      events << [tp.event, tp.method_id]
    end
    tp_one = TracePoint.new(:call, :return, &record_events)
    tp_two = TracePoint.new(:call, :return, &record_events)

    tp_one.enable(target: obj.method(:one)) do
      obj.one
      obj.two # not targeted
    end
    assert_equal([[:call, :one], [:return, :one]], events)
    events.clear

    tp_one.enable(target: obj.method(:one)) do
      obj.one
      tp_two.enable(target: obj.method(:two)) do
        obj.two
      end
      obj.two
      obj.one
    end
    assert_equal(
      [
        [:call,   :one],
        [:return, :one],
        [:call,   :two],
        [:return, :two],
        [:call,   :one],
        [:return, :one],
      ],
      events
    )
  end

  def test_return_event_with_rescue
    obj = Object.new
    def obj.example
      1 if 1 == 1
    rescue
    end
    ok = false
    tp = TracePoint.new(:return) {ok = true}
    tp.enable {obj.example}
    assert ok, "return event should be emitted"
  end

  def test_disable_local_tracepoint_in_trace
    assert_normal_exit <<-EOS
    def foo
      trace = TracePoint.new(:b_return){|tp|
        tp.disable
      }
      trace.enable(target: method(:bar))
    end
    def bar
      100.times{|i|
        foo; foo
      }
    end
    bar
    EOS

    assert_normal_exit(<<-EOS, 'Bug #18730')
    def bar
      42
    end
    tp_line = TracePoint.new(:line) do |tp0|
      tp_multi1 = TracePoint.new(:return, :b_return, :line) do |tp|
        tp0.disable
      end
      tp_multi1.enable
    end
    tp_line.enable(target: method(:bar))
    bar
    EOS
  end

  def test_stat_exists
    assert_instance_of Hash, TracePoint.stat
  end

  def test_tracepoint_opt_invokebuiltin_delegate_leave
    code = 'puts RubyVM::InstructionSequence.of("\x00".method(:unpack)).disasm'
    out = EnvUtil.invoke_ruby(['-e', code], '', true).first
    assert_match(/^0000 opt_invokebuiltin_delegate_leave /, out)

    event = eval(EnvUtil.invoke_ruby(['-e', <<~'EOS'], '', true).first)
      TracePoint.new(:return) do |tp|
        p [tp.event, tp.method_id]
      end.enable do
        "\x00".unpack("c")
      end
    EOS
    assert_equal [:return, :unpack], event
  end

  def test_while_in_while
    lines = []

    TracePoint.new(:line){|tp|
      next unless target_thread?
      lines << tp.lineno
    }.enable{
      n = 3
      while n > 0
        n -= 1 while n > 0
      end
    }
    assert_equal [__LINE__ - 5, __LINE__ - 4, __LINE__ - 3], lines, 'Bug #17868'
  end

  def test_allow_reentry
    event_lines = []
    _l1 = _l2 = _l3 = _l4 = nil
    TracePoint.new(:line) do |tp|
      next unless target_thread?

      event_lines << tp.lineno
      next if (__LINE__ + 2 .. __LINE__ + 4).cover?(tp.lineno)
      TracePoint.allow_reentry do
        _a = 1; _l3 = __LINE__
        _b = 2; _l4 = __LINE__
      end
    end.enable do
      _c = 3; _l1 = __LINE__
      _d = 4; _l2 = __LINE__
    end

    assert_equal [_l1, _l3, _l4, _l2, _l3, _l4], event_lines

    assert_raise RuntimeError do
      TracePoint.allow_reentry{}
    end
  end

  def test_raising_from_b_return_tp_tracing_bmethod
    assert_normal_exit(<<~RUBY, '[Bug #18060]', timeout: 3)
      class Foo
        define_singleton_method(:foo) { return } # a bmethod
      end

      TracePoint.trace(:b_return) do |tp|
        raise
      end

      Foo.foo
    RUBY

    # Same thing but with a target
    assert_normal_exit(<<~RUBY, '[Bug #18060]', timeout: 3)
      class Foo
        define_singleton_method(:foo) { return } # a bmethod
      end

      TracePoint.new(:b_return) do |tp|
        raise
      end.enable(target: Foo.method(:foo))

      Foo.foo
    RUBY
  end

  def helper_cant_rescue
    begin
      raise SyntaxError
    rescue
      cant_rescue
    end
  end

  def test_tp_rescue
    lines = []
    TracePoint.new(:line){|tp|
      next unless target_thread?
      lines << tp.lineno
    }.enable{
      begin
        helper_cant_rescue
      rescue SyntaxError
      end
    }
    _call_line = lines.shift
    _raise_line = lines.shift
    assert_equal [], lines
  end

  def helper_can_rescue
    begin
      raise __LINE__.to_s
    rescue SyntaxError
      :ng
    rescue
      :ok
    end
  end

  def helper_can_rescue_empty_body
    begin
      raise __LINE__.to_s
    rescue SyntaxError
      :ng
    rescue
    end
  end

  def test_tp_rescue_event
    lines = []
    TracePoint.new(:rescue){|tp|
      next unless target_thread?
      lines << [tp.lineno, tp.raised_exception]
    }.enable{
      helper_can_rescue
    }

    line, err, = lines.pop
    assert_equal [], lines
    assert err.kind_of?(RuntimeError)
    assert_equal err.message.to_i + 4, line

    lines = []
    TracePoint.new(:rescue){|tp|
      next unless target_thread?
      lines << [tp.lineno, tp.raised_exception]
    }.enable{
      helper_can_rescue_empty_body
    }

    line, err, = lines.pop
    assert_equal [], lines
    assert err.kind_of?(RuntimeError)
    assert_equal err.message.to_i + 3, line
  end

  def test_tracepoint_thread_begin
    target_thread = nil

    trace = TracePoint.new(:thread_begin) do |tp|
      target_thread = tp.self
    end

    trace.enable(target_thread: nil) do
      Thread.new{}.join
    end

    assert_kind_of(Thread, target_thread)
  end

  def test_tracepoint_thread_end
    target_thread = nil

    trace = TracePoint.new(:thread_end) do |tp|
      target_thread = tp.self
    end

    trace.enable(target_thread: nil) do
      Thread.new{}.join
    end

    assert_kind_of(Thread, target_thread)
  end

  def test_tracepoint_thread_end_with_exception
    target_thread = nil

    trace = TracePoint.new(:thread_end) do |tp|
      target_thread = tp.self
    end

    trace.enable(target_thread: nil) do
      thread = Thread.new do
        Thread.current.report_on_exception = false
        raise
      end

      # Ignore the exception raised by the thread:
      thread.join rescue nil
    end

    assert_kind_of(Thread, target_thread)
  end
end
