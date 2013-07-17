[![Build Status](https://secure.travis-ci.org/JoshCheek/seeing_is_believing.png?branch=master)](http://travis-ci.org/JoshCheek/seeing_is_believing)

Seeing Is Believing
===================

Evaluates a file, recording the results of each line of code.
You can then use this to display output values like Bret Victor does with JavaScript in his talk [Inventing on Principle][inventing_on_principle].
Except, obviously, his is like a million times better.

Also comes with a binary to show how it might be used.

For whatever reason, I can't embed videos, but **here's a ~1 minute [video][video]** showing it off.

Works in Ruby 1.9 and 2.0

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
# $ bin/seeing_is_believing proving_grounds/raises_exception.rb
1 + 1          # => 2
raise "ZOMG!"  # ~> RuntimeError: ZOMG!
1 + 1
```

Use The Lib
===========

```ruby
require 'seeing_is_believing'

believer = SeeingIsBelieving.new("%w[a b c].each do |i|
                                    i.upcase
                                  end")

result = believer.call
result                # => #<SeeingIsBelieving::Result:0x007f832298e340 @max_line_number=3, @min_line_number=1, @results={2=>#<SeeingIsBelieving::Result::Line:0x007f832298df30 @array=["\"A\"", "\"B\"", "\"C\""]>, 3=>#<SeeingIsBelieving::Result::Line:0x007f832298db98 @array=["[\"a\", \"b\", \"c\"]"]>}, @stdout="", @stderr="">

result.to_a           # => [#<SeeingIsBelieving::Result::Line:0x007f832299adc0 @array=[]>,
                      #     #<SeeingIsBelieving::Result::Line:0x007f832298df30 @array=['"A"', '"B"', '"C"']>,
                      #     #<SeeingIsBelieving::Result::Line:0x007f832298db98 @array=['["a", "b", "c"]']>]

result[2]             # => #<SeeingIsBelieving::Result::Line:0x007f832298df30 @array=['"A"', '"B"', '"C"']>

# this result object is a thin wrapper around its array
result[2][0]          # => '"A"'
result[2][1]          # => '"B"'
result[2][2]          # => '"C"'
result[2].join(", ")  # => '"A", "B", "C"'
```

Install
=======


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

Sublime Text 2 Integration
==========================

See [sublime-text-2-seeing-is-believing](https://github.com/JoshCheek/sublime-text-2-seeing-is-believing).


TextMate Integration
====================

Note: This assumes you've already set up Ruby to work with TextMate.
If not, you'll need to start there. [Here](https://rvm.io/integration/textmate/)
are instructions for RVM (I recommend the wrapper approach).
[Here](http://uberfork.com/post/12280974742/integrate-rbenv-with-textmate)
are instructions for rbenv.

Go to the bundle editor, create this new command in the Ruby bundle:

```shell
if [ -z "$TM_FILEPATH" ]; then
  "${TM_RUBY}" -S seeing_is_believing -Ku --result-length 200 --alignment-strategy chunk --timeout 12
else
  "${TM_RUBY}" -S seeing_is_believing -Ku --result-length 200 --as "$TM_FILEPATH" --alignment-strategy chunk --timeout 12
fi
```

It should look like this:

![textmate-integration][textmate-integration]

I also recommend a second command for cleaning the output:

```shell
"${TM_RUBY}" -S seeing_is_believing -Ku --clean
```

Emacs Integration
=================

Add this function to your Emacs configuration:

~~~~ scheme
(defun seeing-is-believing ()
  "Replace the current region (or the whole buffer, if none) with the output
of seeing_is_believing."
  (interactive)
  (let ((beg (if (region-active-p) (region-beginning) (point-min)))
        (end (if (region-active-p) (region-end) (point-max))))
    (shell-command-on-region beg end "seeing_is_believing" nil 'replace)))
~~~~

You can now call `seeing-is-believing` to replace the current region
or current buffer contents with the output of running it through
`seeing_is_believing`.

Known Issues
============

* `BEGIN/END` breaks things and I probably won't take the time to fix it, becuase it's nontrivial and its really meant for command-line scripts, but there is currently a cuke for it
* Heredocs aren't recorded. It might actually be possible if the ExpressionList were to get smarter

Todo
====

* Make a Lines class which is a collection of lines, responsible for managing the trailing newlines in Binary::PrintResultsNextToLines and SeeingIsBelieving/ExpressionList
* Add examples of invocations to the help screen
* Add xmpfilter option to sublime text
* Update TextMate examples to use same keys as sublime, add xmpfilter option on cmd+opt+N
* Move as much of the SyntaxAnalyzer as possible over to Parser and ditch Ripper altogether


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
