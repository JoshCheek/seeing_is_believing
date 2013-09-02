[![Build Status](https://secure.travis-ci.org/JoshCheek/seeing_is_believing.png?branch=master)](http://travis-ci.org/JoshCheek/seeing_is_believing)

Seeing Is Believing
===================

Evaluates a file, recording the results of each line of code.
You can then use this to display output values like Bret Victor does with JavaScript in his talk [Inventing on Principle](http://vimeo.com/36579366).
Except, obviously, his is like a million times better.

Also comes with a binary to show how it might be used.

For whatever reason, I can't embed videos, but **here's a ~1 minute [video](http://vimeo.com/58766950)** showing it off.

Works in Ruby 1.9 and 2.0

Use The Binary
==============

```ruby
$ cat simple_example.rb
5.times do |i|
    i * 2
end


$ seeing_is_believing simple_example.rb
5.times do |i|  # => 5
    i * 2       # => 0, 2, 4, 6, 8
end             # => 5
```

Use The Lib
===========

```ruby
require 'seeing_is_believing'
believer = SeeingIsBelieving.new("[:a, :b, :c].each do |i|
                                    i.upcase
                                  end")

result = believer.call # => #<SIB::Result @results={1=>#<SIB:Line["[:a, :b, :c]"] no exception>, 2=>#<SIB:Line[":A", ":B", ":C"] no exception>, 3=>#<SIB:Line["[:a, :b, :c]"] no exception>}\n  @stdout=""\n  @stderr=""\n  @exitstatus=0\n  @bug_in_sib=nil>

result[2]            # => #<SIB:Line[":A", ":B", ":C"] no exception>
result[2][0]         # => ":A"
result[2][1]         # => ":B"
result[2][2]         # => ":C"
result[2].join(", ") # => ":A, :B, :C"

result.stdout    # => ""
result.stderr    # => ""
result.exception # => nil
```

Install
=======

Currently requires Ruby 1.9 or 2.0 I don't have specific plans to make it available on 1.8,
but it could happen.

    $ gem install seeing_is_believing


Editor Integration
==================

* [sublime-text-2-seeing-is-believing](https://github.com/JoshCheek/sublime-text-2-seeing-is-believing)
* [TextMate 1](https://github.com/JoshCheek/text_mate_1-seeing-is_believing)
* [TextMate 2](https://github.com/JoshCheek/text_mate_2-seeing-is_believing)

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

* `BEGIN/END` breaks things and I probably won't ever fix it, becuase it's annoying and its really meant for command-line scripts... but there is currently a spec for it
* `exit!` ignores callbacks that `SeeingIsBelieving` uses to communicate the results back to the main app. If you call it, `SeeingIsBelieving` will blow up. We could "fix" this by overriding it, but I feel like that would violate the meaning of `exit!`, so basically, just don't call that method.
* The code to find the data segment is naive, and could wind up interpolating results into a string or something

Todo
====

* Make a new video

Shit that will probably never get done (or if it does, won't be until after 2.0)
================================================================================

* How about if begin/rescue/end was able to record the result on the rescue section
* What about recording the result of a line inside of a string interpolation, e.g. "a#{\n1\n}b" could record line 2 is 1 and line 3 is "a\n1\nb"
* Be able to clean an invalid file (used to be able to do this, but parser can't identify comments in an invalid file the way that I'm currently using it, cuke is still there, marked as @not-implemented)
* If given a file with a unicode character, but not set unicode, inform the user

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


