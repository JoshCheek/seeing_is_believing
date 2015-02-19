[![Stories in Ready](https://badge.waffle.io/JoshCheek/seeing_is_believing.png?label=ready&title=Ready)](https://waffle.io/JoshCheek/seeing_is_believing)
[![Build Status](https://secure.travis-ci.org/JoshCheek/seeing_is_believing.png?branch=master)](http://travis-ci.org/JoshCheek/seeing_is_believing)

Seeing Is Believing
===================

Evaluates Ruby code, recording the results of each line.
Integrates with any extensible editor (I've integrated it with many already, see [the list](https://github.com/JoshCheek/seeing_is_believing#editor-integration).

![example](https://s3.amazonaws.com/josh.cheek/images/scratch/sib-example1.gif)

Watch a [longer video](http://vimeo.com/73866851).

Works in Ruby 1.9, 2.0, 2.1, 2.2, rubinius (I **think**, need to make better tests), still trying to get it working with Jruby.

Use The Binary
==============

`cat simple_example.rb`

```ruby
5.times do |i|
  i * 2
end
```

`seeing_is_believing simple_example.rb`
```ruby
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

Currently requires Ruby 1.9 or 2.x

    $ gem install seeing_is_believing


Editor Integration
==================

* [Atom](https://github.com/JoshCheek/atom-seeing-is-believing) (prob has best installation instructions, overall best integration, but config and filesystem events are iffy)
* [Sublime 2 and 3](https://github.com/JoshCheek/sublime-text-2-and-3-seeing-is-believing) (works reasonably, but isn't integrated with the package manager)
* [TextMate 1](https://github.com/JoshCheek/text_mate_1-seeing-is_believing)
* [TextMate 2](https://github.com/JoshCheek/text_mate_2-seeing-is_believing) (TM2 is actually looking really nice these days -- Josh Cheek, 18 Feb 2015)

Vim
===

I didn't write either of these, but they both support Seeing Is Beleiving. I've looked through the code, it works reasonably. One of them, I wound up having to edit the installed package, don't remember which.

* [vim-ruby-xmpfilter](https://github.com/t9md/vim-ruby-xmpfilter)
* [vim-seeing-is-believing](https://github.com/hwartig/vim-seeing-is-believing)

Emacs Integration
=================

Add this function to your Emacs configuration:

```scheme
(defun seeing-is-believing ()
  "Replace the current region (or the whole buffer, if none) with the output
of seeing_is_believing."
  (interactive)
  (let ((beg (if (region-active-p) (region-beginning) (point-min)))
        (end (if (region-active-p) (region-end) (point-max))))
    (shell-command-on-region beg end "seeing_is_believing" nil 'replace)))
```

You can now call `seeing-is-believing` to replace the current region
or current buffer contents with the output of running it through
`seeing_is_believing`.

Known Issues
============

* `begin; else; break; end` this code (an else without a resecue) will emit a warning in Ruby, and is omitted from `Parser`'s AST.
  As such, I doubt that anyone will ever write it. But if you were to write it, it would blow up, because SiB rewrites your code, wrapping every expression that could have a value.
  This code will be wrapped. But using the value is **syntactically** invalid in Ruby, because it constitutes a "void value expression" (aka a pointless timesink and the cause of many bugs in SiB).
  Unfortunately, I can't easily check it to seee if it's void since it's not in the parsed AST.  But it's so edge that I don't think it's worth worrying about.

Version 2
=========

Feature complete, I'll fix bugs in it until version 3 is released, though

Version 3
=========

These need to be done before release:

* Add default to number of captures (1000), require user to explicitly set it to infinity
* Expose markers via the CLI
* Spruce up editor integration
  * Integrate with package managers where they are available
  * Expose options to use the streaming API (update as events are seen)
  * Ship with Traveling Ruby so that new users can just press a button and it works,
    rather than having to figure out all the compmlex ecosystem around installing
  * Would be nice to have real integration with Emacs
  * Would be nice to support Ruby Mine

Version 4
=========

* How about if begin/rescue/end was able to record the result on the rescue section
* How about if you could configure which kinds of results you were interested in
  (e.g. turn on/off recording of method definitions, and other results)
* What about recording the result of a line inside of a string interpolation,
  e.g. "a#{\n1\n}b" could record line 2 is 1 and line 3 is "a\n1\nb"
  This would require smarter annotators.
* Allow debugger to take a filename (ie debug to a file insteaad of to stderr)
* `--cd dir` cd to that dir before executing the code
* `--cd -` cd to the dir of the file being executed before executing it
* `--only-show-lines` output only on specified lines (doesn't change stdout/stderr/exceptions)
* More alignment strategies e.g. `min=40` would align to 40, unless that was too short.
  Could have fallback strategies, so e.g. `-s min=40,fallback=line`
* Package Ruby with the editor downloads so that they don't require you to know so fkn much to set it up.
* Allow user to set marker

Inspiration
===========

* [Xmpfilter](http://www.rubydoc.info/gems/rcodetools/0.8.5.0/Rcodetools/XMPFilter), which is a part of the [rcodetools gem](https://rubygems.org/gems/rcodetools).
* Bret Victor's completely inspiring talk [Inventing on Principle](https://www.youtube.com/watch?v=PUv66718DII).
* My 8th Light mentor, [Doug Bradbury](http://blog.8thlight.com/doug-bradbury/archive.html) who asked me to make it for his Kids Ruby sessions (I don't think we ever finished integrating it, though >.<)

Interestingly, [Swift playground](https://www.youtube.com/watch?v=oY6nQS3MiF8&t=25m51s)
are very similar (though better integrated since they cerce you into using xcode).
Released about a year and a half before them, but maybe I should take advantage of
their marketing anyway: Swift Playgrounds for Ruby!! :P

Shout outs
==========

* Whitequark for all the work on [Parser](http://github.com/whitequark/parser/), which dramatically dramatically improved SiB (I used to have my own horribly shitty line-based parser)
* [Travis CI](https://travis-ci.org/JoshCheek/seeing_is_believing)... I love you times a million! So many difficult bugs have been caught by this.
  It's so easy to work with, astoundingly convenient, helps me guarantee that SiB works on everyone else's computers, too. And it's free since SiB is open source.
  I literally have a Travis CI sticker on my laptop, I love you that much.

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
