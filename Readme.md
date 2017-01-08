[![Stories in Ready](https://badge.waffle.io/JoshCheek/seeing_is_believing.png?label=ready&title=Ready)](https://waffle.io/JoshCheek/seeing_is_believing)
[![Unix Build Status](https://secure.travis-ci.org/JoshCheek/seeing_is_believing.png?branch=master)](http://travis-ci.org/JoshCheek/seeing_is_believing)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/32r7s2skrgm9ubva?svg=true)](https://ci.appveyor.com/project/JoshCheek/seeing-is-believing)


Seeing Is Believing
===================

Evaluates Ruby code, recording the results of each line.
Integrates with any extensible editor (I've integrated it with many already, see [the list](https://github.com/JoshCheek/seeing_is_believing#editor-integration)).
If you like Swift Playgrounds, you'll like SiB.

![example](https://s3.amazonaws.com/josh.cheek/images/scratch/sib-example1.gif)

Watch a [longer video](http://vimeo.com/73866851).


Install
=======

Requires Ruby >= 2.1

```sh
$ gem install seeing_is_believing
```

Verify the install with

```sh
$ seeing_is_believing -e '1 + 1'
1 + 1  # => 2
```


Use The Binary
==============

Given the file `simple_example.rb`

```ruby
5.times do |i|
  i * 2
end
```

`$ seeing_is_believing simple_example.rb` will print:

```ruby
5.times do |i|  # => 5
  i * 2         # => 0, 2, 4, 6, 8
end             # => 5
```

`$ seeing_is_believing simple_example.rb --json` will print:

```json
{"stdout":"","stderr":"","exitstatus":0,"exception":null,"lines":{"1":["5"],"2":["0","2","4","6","8"],"3":["5"]}}
```

Pro Tips
========

These things have been useful for integrating.

If you want to execute from some specific directory (e.g. if your editor is in the wrong directory)
try using `Dir.chdir` at the top of the script.
E.g. I used that [here](https://github.com/JoshCheek/seeing_is_believing/issues/58#issuecomment-91600783)
so I could run with a full Rails app available in "Completely against the real env".

If you want some specific file to be available in that environment, require the fullpath to the file.
Eg I used that [here](https://github.com/JoshCheek/seeing_is_believing/issues/58#issuecomment-91600783)
to load up the Rails schema in "Running against the real schema".

You can also set the `$LOAD_PATH` to a gem you're working on and then require files as if
it was installed.

You work with `gets` by setting `$stdin` to the `DATA` segment and writing inputs there.

```ruby
$stdin = DATA

puts "What's your name?"
name = gets.chomp
puts "What's your favourite colour?"
colour = gets.chomp
puts "#{name}'s favourite colour is #{colour}."

# >> What's your name?
# >> What's your favourite colour?
# >> Josh's favourite colour is brown.

__END__
Josh
brown
```

Rescue lines you expect to explode so that it displays the expected result and continues evaluating.

```ruby
lambda { |x| x }.call()     rescue $!  # => #<ArgumentError: wrong number of arguments (given 0, expected 1)>
lambda { |x| x }.call(1)               # => 1
lambda { |x| x }.call(1, 2) rescue $!  # => #<ArgumentError: wrong number of arguments (given 2, expected 1)>
```

Use `fork` to look at what a program does when run two different ways.

```ruby
class A
  fork && raise("omg")  # => nil
rescue
  $!                    # => #<RuntimeError: omg>
else
  :nothing_raised       # => :nothing_raised
end                     # => #<RuntimeError: omg>, :nothing_raised
```

Use The Lib
===========

```ruby
require 'seeing_is_believing'

# There are a lot of options you can pass here, including a custom handler
handler = SeeingIsBelieving.call("[:a, :b, :c].each do |i|
                                    i.upcase
                                  end")
result = handler.result

result[2]            # => [":A", ":B", ":C"]
result[2][0]         # => ":A"
result[2][1]         # => ":B"
result[2][2]         # => ":C"
result[2].join(", ") # => ":A, :B, :C"

result.stdout    # => ""
result.stderr    # => ""
result.exception # => nil
```



Editor Integration
==================

* [Atom](https://github.com/JoshCheek/atom-seeing-is-believing) (prob has best installation instructions, overall best integration, but config and file system events are iffy)
* [Sublime 2 and 3](https://github.com/JoshCheek/sublime-text-2-and-3-seeing-is-believing) (works reasonably, but isn't integrated with the package manager)
* [TextMate 1](https://github.com/JoshCheek/text_mate_1-seeing-is_believing)
* [TextMate 2](https://github.com/JoshCheek/text_mate_2-seeing-is_believing) (TM2 is actually looking really nice these days -- Josh Cheek, 18 Feb 2015)


Vim
---

These packages support SiB:

* [vim-seeing-is-believing](https://github.com/hwartig/vim-seeing-is-believing)
* [vim-ruby-xmpfilter](https://github.com/t9md/vim-ruby-xmpfilter)

Personally, I had difficulty with them, but this configuration has gotten me pretty far:

```viml
" ===== Seeing Is Believing =====
" Assumes you have a Ruby with SiB available in the PATH
" If it doesn't work, you may need to `gem install seeing_is_believing -v 3.0.0.beta.6`
" ...yeah, current release is a beta, which won't auto-install

" Annotate every line
  nmap <leader>b :%!seeing_is_believing --timeout 12 --line-length 500 --number-of-captures 300 --alignment-strategy chunk<CR>;
" Annotate marked lines
  nmap <leader>n :%.!seeing_is_believing --timeout 12 --line-length 500 --number-of-captures 300 --alignment-strategy chunk --xmpfilter-style<CR>;
" Remove annotations
  nmap <leader>c :%.!seeing_is_believing --clean<CR>;
" Mark the current line for annotation
  nmap <leader>m A # => <Esc>
" Mark the highlighted lines for annotation
  vmap <leader>m :norm A # => <Esc>
```


Emacs Integration
-----------------

You can use my friend's configuration [file](https://github.com/jcinnamond/seeing-is-believing).
You can see him use it in [this](http://brightonruby.com/2016/the-point-of-objects-john-cinnamond/?utm_source=rubyweekly&utm_medium=email)
presentation at 10 minutes.

Alternatively, adding this function to your Emacs configuration will get you pretty far:

```scheme
(defun seeing-is-believing ()
  "Replace the current region (or the whole buffer, if none) with the output
of seeing_is_believing."
  (interactive)
  (let ((beg (if (region-active-p) (region-beginning) (point-min)))
        (end (if (region-active-p) (region-end) (point-max)))
        (origin (point)))
    (shell-command-on-region beg end "seeing_is_believing" nil 'replace)
    (goto-char origin)))
```

You can now call `seeing-is-believing` to replace the current region
or current buffer contents with the output of running it through
`seeing_is_believing`.


Features
========

Check the [features](features) directory.


Known Issues
============

* `begin; else; break; end` this code (an else without a rescue) will emit a warning in Ruby, and is omitted from `Parser`'s AST.
  As such, I doubt that anyone will ever write it. But if you were to write it, it would blow up, because SiB rewrites your code, wrapping every expression that could have a value.
  This code will be wrapped. But using the value is **syntactically** invalid in Ruby, because it constitutes a "void value expression" (aka a pointless time sink and the cause of many bugs in SiB).
  Unfortunately, I can't easily check it to see if it's void since it's not in the parsed AST.  But it's so edge that I don't think it's worth worrying about.

Setting up Development
======================

* Make sure you have Ruby (I use [chruby](https://github.com/postmodern/chruby) and [ruby-install](https://github.com/postmodern/ruby-install) for this).
* Make sure you have bundler and rake (`gem install bundler rake`)
* Fork the repo (there's a button on Github)
* Clone your fork (`git clone git@github.com:YOUR_GITHUB_NAME/seeing_is_believing.git`)
* Install the dependencies (`rake install`) This approach is painful, but it means the test suite is like 30s instead of 5min.
* Get a list of rake tasks (`rake -T`)
* Run the full test suite (`rake`)
* Run the rspec tests `bundle exec rspec` from here you can pass options you want, such as a tag for the tests you're interested in.
* Run the Cucumber tests `bundle exec cucumber` (these literally invoke the executable, as a user would)


Some stuff that might happen one day
====================================

* Add default to number of captures (1000), require user to explicitly set it to infinity
* Expose markers via the CLI
* Spruce up editor integration
  * Integrate with package managers where they are available
  * Expose options to use the streaming API (update as events are seen)
  * Ship with Traveling Ruby so that new users can just press a button and it works,
    rather than having to figure out all the complex ecosystem around installing
  * Would be nice to have real integration with Emacs
  * Would be nice to support Ruby Mine
* How about if begin/rescue/end was able to record the result on the rescue section
* How about if you could configure which kinds of results you were interested in
  (e.g. turn on/off recording of method definitions, and other results)
* What about recording the result of a line inside of a string interpolation,
  e.g. "a#{\n1\n}b" could record line 2 is 1 and line 3 is "a\n1\nb"
  This would require smarter annotators.
* Allow debugger to take a filename (i.e. debug to a file instead of to stderr)
* `--cd dir` cd to that directory before executing the code
* `--cd -` cd to the directory of the file being executed before executing it
* `--only-show-lines` output only on specified lines (doesn't change stdout/stderr/exceptions)
* More alignment strategies e.g. `min=40` would align to 40, unless that was too short.
  Could have fallback strategies, so e.g. `-s min=40,fallback=line`
* Package Ruby with the editor downloads so that they don't require you to know so much to set it up.
* Allow user to set marker
* Maybe rename xmpfilter style, not many people know what that is, so the name doesn't help users


Inspiration
===========

* [Xmpfilter](http://www.rubydoc.info/gems/rcodetools/0.8.5.0/Rcodetools/XMPFilter), which is a part of the [rcodetools gem](https://rubygems.org/gems/rcodetools).
* Bret Victor's completely inspiring talk [Inventing on Principle](https://www.youtube.com/watch?v=PUv66718DII).
* My 8th Light mentor, [Doug Bradbury](http://blog.8thlight.com/doug-bradbury/archive.html) who asked me to make it for his Kids Ruby sessions (I don't think we ever finished integrating it, though >.<)


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
