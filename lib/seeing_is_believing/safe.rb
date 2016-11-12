# require this before anything else, b/c it expects the world to be sane when it is loaded
class SeeingIsBelieving
  module Safe
    refine Class do
      alias === ===
    end

    refine Queue do
      alias <<    <<
      alias shift shift
      alias clear clear
    end

    refine IO do
      alias sync= sync=
      alias <<    <<
      alias flush flush
      alias close close
    end

    refine Symbol do
      alias ==      ==
      alias to_s    to_s
      alias inspect inspect
    end

    refine Symbol.singleton_class do
      alias define_method define_method
      alias class_eval    class_eval
    end

    refine String do
      alias ==     ==
      alias to_s   to_s
      alias to_str to_str
    end

    refine Fixnum do
      alias to_s to_s
      alias next next
      alias <    <
    end

    refine Array do
      alias pack pack
      alias map  map
      alias size size
      alias join join
      alias []   []
      alias []=  []=
    end

    refine Hash do
      alias []  []
      alias []= []=
    end

    refine Hash.singleton_class do
      alias new new
    end

    refine Marshal.singleton_class do
      alias dump dump
    end

    refine Exception do
      alias message   message
      alias backtrace backtrace
      alias class     class
    end

    refine Exception.singleton_class do
      alias define_method define_method
      alias class_eval    class_eval
    end

    refine Thread do
      alias join join
    end

    refine Thread.singleton_class do
      alias current current
    end

    refine Method do
      alias call call
    end

    refine Proc do
      alias call call
    end

    refine Object do
      alias block_given? block_given?
    end
  end
end
