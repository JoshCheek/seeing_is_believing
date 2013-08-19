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

Go to the bundle editor, create a new command (I put it in the Ruby bundle)
You can name it what you want, I went with "seeing is believing annotate all lines"

```shell
#!/bin/bash

# set result length because TextMate has difficulty displaying long lines
default_options=""
default_options="$default_options -Ku"
default_options="$default_options --result-length 200"
default_options="$default_options --alignment-strategy chunk"
default_options="$default_options --timeout 12"

if [ -z "$TM_FILEPATH" ]; then
  "${TM_RUBY}" -S seeing_is_believing $default_options
else
  "${TM_RUBY}" -S seeing_is_believing $default_options --as "$TM_FILEPATH"
fi
```

You can also make one for annotating only the lines you have marked.
I named it "seeing is believing annotate marked lines"

```shell
#!/bin/bash

# set result length because TextMate has difficulty displaying long lines
default_options=""
default_options="$default_options --xmpfilter-style"
default_options="$default_options -Ku"
default_options="$default_options --result-length 200"
default_options="$default_options --alignment-strategy chunk"
default_options="$default_options --timeout 12"

if [ -z "$TM_FILEPATH" ]; then
  "${TM_RUBY}" -S seeing_is_believing $default_options
else
  "${TM_RUBY}" -S seeing_is_believing $default_options --as "$TM_FILEPATH"
fi
```

And you'll probably want one to clean out the outpt

```shell
#!/bin/bash
"${TM_RUBY}" -S seeing_is_believing -Ku --clean
```

You can bind them to whatever keys you want, but I'll recomend (for consistency with what I chose for the Sublime bundle)
* annotate all lines -> Command Option b
* annotate marked lines -> Command Option n
* remove annotations -> Command Option v

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

Todo
====

* Sublime: Merge xmpfilter option into main after 2.0 release
* Make TextMate 2 bundle
* Make a new video

Shit that will probably never get done (or if it does, won't be until after 2.0)
================================================================================

* How about if begin/rescue/end was able to record the result on the rescue section
* What about recording the result of a line inside of a string interpolation, e.g. "a#{\n1\n}b" could record line 2 is 1 and line 3 is "a\n1\nb"
* Add a flag to allow you to just get the results so that it can be easily used without a Ruby runtime (difficult in that its unclear how to separate line output from stdout, stderr, exit status, exceptions, etc. Maybe just serialize the result as JSON?)
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



[inventing_on_principle]: http://vimeo.com/36579366
[textmate-integration]:   https://raw.github.com/JoshCheek/seeing_is_believing/master/textmate-integration.png
[video]:                  http://vimeo.com/58766950
