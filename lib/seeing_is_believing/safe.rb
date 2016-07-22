class SeeingIsBelieving
  module Safe
    def self.build(klass, *method_names)
      options = {}
      options = method_names.pop if method_names.last.kind_of? ::Hash

      Class.new do
        class << self
          alias [] new
        end

        define_method :initialize do |instance|
          @_instance = instance
        end

        methods = method_names.map { |name| [name, klass.instance_method(name)] }
        methods.each do |name, method|
          define_method(name) do |*args, &block|
            method.bind(@_instance).call(*args, &block)
          end
        end

        singleton_methods = options.fetch(:class, []).map { |name| [name, klass.method(name)] }
        singleton_methods.each do |name, method|
          define_singleton_method name do |*args, &block|
            method.call(*args, &block)
          end
        end
      end
    end

    Queue     = build ::Queue, :<<, :shift, :clear
    Stream    = build ::IO, :sync=, :<<, :flush, :close
    Symbol    = build ::Symbol, :==, class: [:define_method]
    String    = build ::String, :to_s
    Fixnum    = build ::Fixnum, :to_s
    Array     = build ::Array, :pack, :map, :size, :join
    Hash      = build ::Hash, :[], :[]=, class: [:new]
    Marshal   = build ::Marshal, class: [:dump]
    Exception = build ::Exception, :message, :backtrace, :class, class: [:define_method]
    Thread    = build ::Thread, :join, class: [:current]
  end
end
