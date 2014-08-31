[![Stories in Ready](https://badge.waffle.io/JoshCheek/seeing_is_believing.png?label=ready&title=Ready)](https://waffle.io/JoshCheek/seeing_is_believing)
[![Build Status](https://secure.travis-ci.org/JoshCheek/seeing_is_believing.png?branch=master)](http://travis-ci.org/JoshCheek/seeing_is_believing)

Seeing Is Believing
===================

Evaluates a file, recording the results of each line of code.
Integrates with any extensible editor (I've integrated it with many already, see [the list](https://github.com/JoshCheek/seeing_is_believing#editor-integration).

![example](https://s3.amazonaws.com/josh.cheek/images/scratch/sib-example1.gif)

Watch a [longer video](http://vimeo.com/73866851).

Works in Ruby 1.9, 2.0, 2.1, rubinius (I **think**, need to make better tests), still trying to get it working with Jruby.

Use The Binary
==============

* Show every line of code (last expression)
* Show only marked lines (xmpfilter style, except better b/c it understands expressions)
* Clear annotations when they get in your way (even if code is invalid)
* Smart enough to show
  * method arguments
  * if statement clauses
  * values in a hash
  * methods that are chained together across lines
  * multiline string/symbol/regex

```sh
$ cat simple_example.rb
5.times do |i|
  i * 2
end


$ seeing_is_believing simple_example.rb
5.times do |i|  # => 5
  i * 2         # => 0, 2, 4, 6, 8
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

Currently requires Ruby 1.9 or 2.0.

    $ gem install seeing_is_believing


Editor Integration
==================

* [sublime-text-2-seeing-is-believing](https://github.com/JoshCheek/sublime-text-2-seeing-is-believing)
* [TextMate 1](https://github.com/JoshCheek/text_mate_1-seeing-is_believing)
* [TextMate 2](https://github.com/JoshCheek/text_mate_2-seeing-is_believing)
* [vim-ruby-xmpfilter](https://github.com/t9md/vim-ruby-xmpfilter) (has support for `seeing_is_believing`)
* [vim-seeing-is-believing](https://github.com/hwartig/vim-seeing-is-believing)
* [atom-seeing-is-believing](https://github.com/JoshCheek/atom-seeing-is-believing) (prob has best installation instructions)

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

* `BEGIN/END` breaks things and I probably won't ever fix it, because it's annoying and it's really meant for command-line scripts... but there is currently a spec for it.
* `exit!` ignores callbacks that `SeeingIsBelieving` uses to communicate the results back to the main app. If you call it, `SeeingIsBelieving` will blow up. We could "fix" this by overriding it, but I feel like that would violate the meaning of `exit!`, so basically, just don't call that method.
* The code to find the data segment is naive, and could wind up interpolating results into a string or something.

Shit that will probably never get done (or if it does, won't be until after 2.0)
================================================================================

* How about if begin/rescue/end was able to record the result on the rescue section
* How about if you could configure which kinds of results ou were interested in (e.g. turn on/off recording of method definitions, and other results)
* What about recording the result of a line inside of a string interpolation, e.g. "a#{\n1\n}b" could record line 2 is 1 and line 3 is "a\n1\nb"
* If given a file with a Unicode character, but not set Unicode, inform the user

License
=======

<a href="http://www.wtfpl.net/"><img src="http://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl.svg" height="20" alt="WTFPL" /></a>

    Copyright (C) 2014 Josh Cheek <josh.cheek@gmail.com>

    This program is free software. It comes without any warranty,
    to the extent permitted by applicable law.
    You can redistribute it and/or modify it under the terms of the
    Do What The Fuck You Want To Public License,
    Version 2, as published by Sam Hocevar.
    See http://www.wtfpl.net/ for more details.
