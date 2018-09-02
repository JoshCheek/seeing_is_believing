class SeeingIsBelieving
  module Compatibility
    refine String do
      unless String.instance_methods.include? :scrub
        # b/c it's not implemented on 2.0.0
        def scrub(char=nil, &block)
          char && block = lambda { |c| char }
          each_char.inject("") do |new_str, char|
            if char.valid_encoding?
              new_str << char
            else
              new_str << block.call(char)
            end
          end
        end
      end
    end
  end
end
