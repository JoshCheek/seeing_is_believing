Seeing Is Believing
===================

Evaluates a file, recording the results of each line of code.
You can then use this to display output values like Bret Victor does with JavaScript in his talk [Inventing on Principle][inventing_on_principle].
Except, obviously, his is like a million better.

Reeaally rough at the moment, but it works for simple examples.

Also comes with a binary to show how it might be used.

Use The Binary
==============

```ruby
# $ seeing_is_believing proving_grounds/basic_functionality.rb
5.times do |i|
  i * 2         # => 0, 2, 4, 6, 8
end             # => 5

def meth(n)
  n             # => "12", "34"
end             # => nil

# some invocations
meth "12"       # => "12"
meth "34"       # => "34"
```

```ruby
# $ bin/seeing_is_believing proving_grounds/raises_exception.rb 2>/dev/null
1 + 1          # => 2
raise "ZOMG!"  # ~> RuntimeError: ZOMG!
1 + 1
```

```bash
# $ bin/seeing_is_believing proving_grounds/raises_exception.rb 1>/dev/null
ZOMG!
```

Use The Lib
===========

```ruby
require 'seeing_is_believing'

believer = SeeingIsBelieving.new("%w[a b c].each do |i|
                                    i.upcase
                                  end")

result = believer.call
result      # => #<SeeingIsBelieving::Result:0x007faeed1a5b78 @max_line_number=3, @min_line_number=1, @results={2=>['"A"', '"B"', '"C"'], 3=>['["a", "b", "c"]']}>

result.to_a # => [ [1, []],
            #      [2, ['"A"', '"B"', '"C"']],
            #      [3, ['["a", "b", "c"]']]
            #    ]

result[2]   # => ['"A"', '"B"', '"C"']
```

Install
=======

    $ gem install seeing_is_believing

Or if you haven't fixed your gem home, and you aren't using any version managers:

    $ sudo gem install seeing_is_believing

Known Issues
============

* No idea what happens if you give it a syntactically invalid file. It probably just raises an exception, but might possibly freeze up or something.
* `return` keyword and heredocs break things, `__END__` probably does too, maybe also `BEGIN/END` and `=begin/=end`
* There are expressions which continue on the next line even though the previous line is a valid expression, e.g. "3\n.times { |i| i }" which will blow up. This is a fundamental flaw in the algorithm and will either require a smarter algorithm, or some sort of more sophisticated parsing in order to handle correctly

License
=======

           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                       Version 2, December 2004

    Copyright (C) 2012 Josh Cheek <josh.cheek@gmail.com>

    Everyone is permitted to copy and distribute verbatim or modified
    copies of this license document, and changing it is allowed as long
    as the name is changed.

               DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
      TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

     0. You just DO WHAT THE FUCK YOU WANT TO.



[inventing_on_principle]: http://vimeo.com/36579366
