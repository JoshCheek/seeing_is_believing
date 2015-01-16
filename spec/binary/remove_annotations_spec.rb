require 'spec_helper'
require 'seeing_is_believing/binary/remove_annotations'
require 'seeing_is_believing/binary/data_structures'

RSpec.describe SeeingIsBelieving::Binary::RemoveAnnotations do
  def regexes
    SeeingIsBelieving::Binary::Markers.new
  end

  def call(code, should_clean_values=true)
    indentation = code[/\A */]
    code        = code.gsub /^#{indentation}/, ''
    code << "\n" unless code.end_with? "\n"
    described_class.call(code, should_clean_values, regexes).chomp
  end

  context 'when there are lines that are just normal comments' do
    example { expect(call "1 # hello").to eq "1 # hello" }
    example { expect(call "1 # hello\n"\
                          "# world").to eq "1 # hello\n"\
                                           "# world" }
    example { expect(call "1 # not special\n"\
                          "2 # => 3").to eq "1 # not special\n2" }
  end

  context 'when told to clean out value annotations' do
    example { expect(call "1# => 1",    true).to eq "1"   }
    example { expect(call "1 # => 1",   true).to eq "1"   }
    example { expect(call "1  # => 1",  true).to eq "1"   }
    example { expect(call "1  # => 1",  true).to eq "1"   }
    example { expect(call "1   # => 1", true).to eq "1"   }
    example { expect(call "1  # =>  1", true).to eq "1"   }
    example { expect(call "1  #  => 1", true).to eq "1"   }
    example { expect(call "\n1 # => 1", true).to eq "\n1" }
  end

  context 'when told not to clean out value markers, it leaves the marker, but removes the annotation and trailing whitespace' do
    example { expect(call "1# => 1",    false).to eq "1# =>"    }
    example { expect(call "1 # => 1",   false).to eq "1 # =>"   }
    example { expect(call "1  # => 1",  false).to eq "1  # =>"  }
    example { expect(call "1  # => 1",  false).to eq "1  # =>"  }
    example { expect(call "1   # => 1", false).to eq "1   # =>" }
    example { expect(call "1  # =>  1", false).to eq "1  # =>"  }
    example { expect(call "1  #  => 1", false).to eq "1  #  =>" }
    example { expect(call "\n1 # => 1", false).to eq "\n1 # =>" }
  end

  context 'cleaning inline exception annotations' do
    example { expect(call "1# ~> 1"   ).to eq "1"   }
    example { expect(call "1 # ~> 1"  ).to eq "1"   }
    example { expect(call "1  # ~> 1" ).to eq "1"   }
    example { expect(call "1  # ~> 1" ).to eq "1"   }
    example { expect(call "1   # ~> 1").to eq "1"   }
    example { expect(call "1  # ~>  1").to eq "1"   }
    example { expect(call "\n1 # ~> 1").to eq "\n1" }

    example { expect(call "# >> 1").to   eq ""      }
    example { expect(call "# !> 1").to   eq ""      }
  end

  context 'cleaning multiline results' do
    it 'cleans values whose hash and value locations exactly match the annotation on the line prior' do
      expect(call "1# => 2\n"\
                  " #    3").to eq "1"
    end

    it 'does not clean values where the comment appears at a different position' do
      expect(call "1# => 2\n"\
                  "#    3").to eq "1\n"\
                                  "#    3"

      expect(call "1# => 2\n"\
                  "  #    3").to eq "1\n"\
                                    "  #    3"

      expect(call "1# => 2\n"\
                  "#     3").to eq "1\n"\
                                   "#     3"
      expect(call "1# => 2\n"\
                  "  #   3").to eq "1\n"\
                                   "  #   3"

    end

    it 'does not clean values where the nextline value appears before the initial annotation value' do
      # does clean
      expect(call "1# => 2\n"\
                  " #    3").to eq "1"
      expect(call "1# => 2\n"\
                  " #     3").to eq "1"

      # does not clean
      expect(call "1# => 2\n"\
                  " #  3 4").to eq "1\n"\
                                   " #  3 4"
      expect(call "1# => 2\n"\
                  " #   3").to eq "1\n"\
                                  " #   3"
      expect(call "1# => 2\n"\
                  " #  3").to eq "1\n"\
                                 " #  3"
    end

    it 'does not clean values where there is content before the comment' do
      expect(call "1# => 2\n"\
                  "3#    4").to eq "1\n"\
                                   "3#    4"
    end

    it 'cleans successive rows of these' do
      expect(call "1# => 2\n"\
                  " #    3\n"\
                  " #    4" ).to eq "1"
      expect(call "1# => 2\n"\
                  " #    3\n"\
                  " #    4\n"\
                  "5# => 6\n"\
                  " #    7\n"\
                  " #    8" ).to eq "1\n5"
    end

    it 'does not clean values where there is non-annotation inbetween' do
      expect(call "1# => 2\n"\
                  "#    3\n"\
                  " #    4").to eq "1\n"\
                                   "#    3\n"\
                                   " #    4"

      expect(call "1# => 2\n"\
                  "3      \n"\
                  " #    4").to eq "1\n"\
                                   "3      \n"\
                                   " #    4"
      expect(call "1# => 2\n"\
                  "#    3\n"\
                  " #    4").to eq "1\n"\
                                   "#    3\n"\
                                   " #    4"
    end

    it 'cleans multiline portion, regardless of whether cleaning values (this is soooooo xmpfilter specific)' do
      expect(call "1# => 2\n"\
                  " #    3").to eq "1"

      expect(call "1# => 2\n"\
                  " #    3",
                  false).to eq "1# =>"
    end

    it 'works on inline exceptions' do
      expect(call "1# ~> 2\n"\
                  " #    3").to eq "1"
    end
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

    example { expect(call <<-CODE.gsub(/^\s*/, '')).to eq "\n1" }

    # >> err
    1
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

    example { expect(call <<-CODE.gsub(/^\s*/, '')).to eq "\n1" }

    # !> err
    1
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
