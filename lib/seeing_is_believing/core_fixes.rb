require 'open3'
module Kernel
  # there is a bug (tested in MRI 2.1)
  # where Kernel#system prints directly to the original
  # stdout and stderr, so you can't hijack the output
  # which, of course, fucks sib up b/c it needs to capture this output
  # and it then uses stdout to render its data structure.
  # builtin Kernel#system avoids being captured
  # and spews data into stdout, causing the invoking process
  # to be unable to parse the result out of the stdout
  def system(*args)
    out, err, status = Open3.capture3(*args)
    $stdout.print out
    $stderr.print err
    status.success?
  end
end
