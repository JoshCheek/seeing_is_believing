puts "SIMPLECOV LOADED"

# no_defaults loads the lib without its at_exit hook
# (the at_exit hook calls Kernel.exit, which raises a SystemExit, overriding whatever the file raised)
require 'simplecov/no_defaults'

# b/c we aren't getting their at_exit hook,
# nothing will write the result to the coverage directory
at_exit { SimpleCov.result.format! }

null_formatter = Class.new { def format(*) end }
SimpleCov.start do
  self.formatter = null_formatter
  add_filter "/spec/"
  add_filter "/features/"
end

