Seeing Is Believing
===================

Evaluates a file, recording the results of each line of code.
You can then use this to display output values like Bret Victor does with JavaScript in his talk ["Inventing on Principle"][inventing_on_principle].
Except, obviously, his is like a million better.

Reeaally rough at the moment, but it works for simple examples.

Also comes with a binary to show how it might be used.

Install
=======

    gem install seeing_is_believing

Use
===

    $ cat proving_grounds/f.rb

```ruby
a = '12'
a + a

5.times do |i|
  i * 2
end
```

    $ seeing_is_believing proving_grounds/f.rb

```ruby
a = '12'        # => "12"
a + a           # => "1212"

5.times do |i|
  i * 2         # => 0, 2, 4, 6, 8
end             # => 5
```

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
