Seeing Is Believing
===================

Evaluates a file, recording the results of each line of code.
You can then use this to display output values like Bret Victor does with JavaScript in his talk [Inventing on Principle][inventing_on_principle].
Except, obviously, his is like a million better.

Also comes with a binary to show how it might be used.

For whatever reason, I can't embed videos, but **here's a ~1 minute [video][video]** showing it off.


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

When Rubygems gets back up:

    $ gem install seeing_is_believing

Or if you haven't fixed your gem home, and you aren't using any version managers:

    $ sudo gem install seeing_is_believing

Rubygems is allowing pushes again, but if it goes back down, you can install like this:

    $ git clone https://github.com/JoshCheek/seeing_is_believing/
    $ cd seeing_is_believing
    $ gem build seeing_is_believing.gemspec
    $ gem install seeing_is_believing-0.0.8.gem
    $ cd ..
    $ rm -rf "./seeing_is_believing"

Hook it into TextMate
=====================

Go to the bundle editor, create this new command in the Ruby bundle:

    "${TM_RUBY}" -r seeing_is_believing/binary -e '
      SeeingIsBelieving::Binary.new(ARGV, $stdin, $stdout, $stderr).call
    '  $TM_FILEPATH 2>/dev/null

It should look like this:

![textmate-integration][textmate-integration]

Known Issues
============

* `BEGIN/END` breaks things and I probably won't take the time to fix it, becuase it's nontrivial and its really meant for command-line scripts, but there is currently a cuke for it
* Heredocs aren't recorded. It might actually be possible if the ExpressionList were to get smarter
* Return statements are dealt with poorly, causing some situations where you could capture and display a value to not capture

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
[textmate-integration]:   https://raw.github.com/JoshCheek/seeing_is_believing/master/textmate-integration.png
[video]:                  http://vimeo.com/58766950
