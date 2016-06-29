class SeeingIsBelieving
  module Safe
    def self.build(klass, *method_names)
      Class.new do
        methods = method_names.map { |name| [name, klass.instance_method(name)] }
        define_method :initialize do |instance|
          @_instance = instance
        end
        methods.each do |name, method|
          define_method(name) do |*args, &block|
            method.bind(@_instance).call(*args, &block)
          end
        end
      end
    end

    Queue   = build ::Queue, :<<, :shift, :clear
    Stream  = build ::IO, :sync=, :<<, :flush, :close
    Symbol  = build ::Symbol, :==
    String  = build ::String, :to_s
    Fixnum  = build ::Fixnum, :to_s
    Array   = build ::Array, :pack, :map
    Marshal = build(::Marshal.singleton_class, :dump).new(::Marshal)
  end
end
