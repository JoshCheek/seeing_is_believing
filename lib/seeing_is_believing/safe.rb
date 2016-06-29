class SeeingIsBelieving
  module Safe
    def self.build(klass, *method_names)
      Class.new do
        methods = method_names.map { |name| [name, klass.instance_method(name)] }
        define_method :initialize do |instance|
          @methods = methods.map { |name, method| [name, method.bind(instance)] }.to_h
        end
        method_names.each do |name|
          define_method(name) { |*args, &block| @methods[name].call(*args, &block) }
        end
      end
    end

    Queue  = build ::Queue, :<<, :shift, :clear
    Stream = build ::IO, :sync=, :<<, :flush, :close
    Symbol = build ::Symbol, :==
  end
end
