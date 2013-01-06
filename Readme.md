Seeing Is Believing
===================

Evaluates a file, recording the results of each line of code.
You can then use this to display output values like Bret Victor does with JavaScript in his talk [Inventing on Principle][inventing_on_principle].
Except, obviously, his is like a million better.

Reeaally rough at the moment, but it works for simple examples.

Also comes with a binary to show how it might be used.

Use
===

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

Install
=======

    $ gem install seeing_is_believing

Or if you haven't fixed your gem home, and you aren't using any version managers:

    $ sudo gem install seeing_is_believing

Known Issues
============

* comments will kill it, probably going to have to actually parse the code to fix this
* I have no idea what happens if you talk to stdout/stderr directly. This should become a non-issue if we evaluate it in its own process like xmpfilter.
* If it dies, it will take your program with it. Same as above. (e.g. running the binary against itself will cause it to recursively invoke itself forever WARNING: DON'T REALLY DO THAT, ITS CRAYAZAY)
* No idea what happens if you give it a syntactically invalid file. It probably just raises an exception, but might possibly freeze up or something.
* return keyword and heredocs break things, __END__ probably does too, maybe also BEGIN/END and =begin/=end

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
