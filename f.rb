require 'stringio'

File.open '/dev/null', 'w' do |black_hole|
  $stdout = STDOUT = black_hole
  puts 'Stdout goes into the black hole'
  system 'echo but system still gets through... bug?'
end
