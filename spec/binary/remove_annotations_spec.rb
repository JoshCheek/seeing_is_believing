require 'spec_helper'
require 'seeing_is_believing/binary/remove_annotations'

RSpec.describe SeeingIsBelieving::Binary::RemoveAnnotations do
  def call(code, should_clean_values=true)
    indentation = code[/\A */]
    code        = code.gsub /^#{indentation}/, ''
    described_class.call(code,
                         should_clean_values,
                         value:              '# => ',
                         exception:          '# ~> ',
                         stdout:             '# >> ',
                         stderr:             '# !> ',
                         xmpfilter_nextline: '#    ',
                        ).chomp
  end

  context 'when told to clean out value annotations' do
    example { expect(call "1# => 1",      true).to eq "1" }
    example { expect(call "1 # => 1",     true).to eq "1" }
    example { expect(call "1  # => 1",    true).to eq "1" }
    example { expect(call "1  # => 1",   true).to eq "1" }
    example { expect(call "1   # => 1",  true).to eq "1" }
    example { expect(call "1  # =>  1",  true).to eq "1" }
    example { expect(call "\n1 # => 1", true).to eq "\n1" }
  end

  context 'when told not to clean out value annotations' do
    example { expect(call "1# => 1",      false).to eq "1# => 1" }
    example { expect(call "1 # => 1",     false).to eq "1 # => 1" }
    example { expect(call "1  # => 1",    false).to eq "1  # => 1" }
    example { expect(call "1  # => 1",   false).to eq "1  # => 1" }
    example { expect(call "1   # => 1",  false).to eq "1   # => 1" }
    example { expect(call "1  # =>  1",  false).to eq "1  # =>  1" }
    example { expect(call "\n1 # => 1", false).to eq "\n1 # => 1" }
  end

  context 'cleaning inline exception annotations' do
    example { expect(call "1# ~> 1"     ).to eq "1" }
    example { expect(call "1 # ~> 1"    ).to eq "1" }
    example { expect(call "1  # ~> 1"   ).to eq "1" }
    example { expect(call "1  # ~> 1"  ).to eq "1" }
    example { expect(call "1   # ~> 1" ).to eq "1" }
    example { expect(call "1  # ~>  1" ).to eq "1" }
    example { expect(call "\n1 # ~> 1").to eq "\n1" }

    example { expect(call "# >> 1").to eq "" }
    example { expect(call "# !> 1").to eq "" }
  end

  context 'cleaning stdout annotations' do
    example { expect(call(<<-CODE)).to eq "1" }
    1
    # >> 2
    CODE

    example { expect(call(<<-CODE)).to eq "1" }
    1

    # >> 2
    CODE

    example { expect(call(<<-CODE)).to eq "1\n" }
    1


    # >> 2
    CODE

    example { expect(call(<<-CODE)).to eq "1\n" }
    1


      # >> 2
    # >> 2
     # >> 2
    CODE


    example { expect(call(<<-CODE)).to eq "1\n" }
    1


    # >> 2
    # >> 3
    CODE
  end

  context 'cleaning stderr annotations' do
    example { expect(call(<<-CODE)).to eq "1" }
    1
    # !> 2
    CODE

    example { expect(call(<<-CODE)).to eq "1" }
    1

    # !> 2
    CODE

    example { expect(call(<<-CODE)).to eq "1" }
    1

    # !> 2
    # !> 3
    CODE

    example { expect(call(<<-CODE)).to eq "1\n" }
    1


      # !> 2
    # !> 2
     # !> 2
    CODE
  end


  context 'cleaning end of file exception annotations' do
    example { expect(call(<<-CODE)).to eq "1" }
    1
    # ~> 2
    CODE

    example { expect(call(<<-CODE)).to eq "1" }
    1

    # ~> 2
    CODE

    example { expect(call(<<-CODE)).to eq "1" }
    1

    # ~> 2
    # ~> 3
    CODE

    example { expect(call(<<-CODE)).to eq "1\n" }
    1


      # ~> 2
    # ~> 2
     # ~> 2
    CODE

    example { expect(call(<<-CODE)).to eq "1\n" }
    1 # ~> error


      # ~> error again
    CODE
  end

  context 'putting it all together' do
    example { expect(call(<<-CODE)).to eq "1" }
    1

    # >> 1
    # >> 2

    # !> 3
    # !> 4

    # ~> 5
    # ~> 6
    CODE

    example { expect(call(<<-CODE)).to eq "1" }
    1

    # >> 1

    # >> 2

    # !> 3

    # !> 4

    # ~> 5

    # ~> 6
    CODE

    example { expect(call(<<-CODE)).to eq "1" }
    1

    # >> 1
    # >> 2
    # !> 3
    # !> 4
    # ~> 5
    # ~> 6
    CODE

    example { expect(call(<<-CODE)).to eq "1\n3" }
    1
    # >> 1
    # >> 2
    3
    # !> 4
    # !> 5
    CODE

    example { expect(call(<<-CODE)).to eq "1\n3\n6" }
    1
    # >> 1
    # >> 2
    3
    # !> 4
    # !> 5
    6
    # ~> 7
    # ~> 8
    CODE

    example { expect(call(<<-CODE)).to eq "1\n\nputs \"omg\"" }
    1  # => 1

    puts "omg"  # ~> RuntimeError: omg

    # ~> RuntimeError
    CODE
  end
end
