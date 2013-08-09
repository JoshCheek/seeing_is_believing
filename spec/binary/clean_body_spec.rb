require 'seeing_is_believing/binary/clean_body'

describe SeeingIsBelieving::Binary::CleanBody do
  def call(code, should_clean_values=true)
    indentation = code[/\A */]
    code        = code.gsub /^#{indentation}/, ''
    described_class.call(code, should_clean_values).chomp
  end

  context 'when told to clean out value annotations' do
    example { call("1#=>1", true).should == "1" }
    example { call("1 #=>1", true).should == "1" }
    example { call("1  #=>1", true).should == "1" }
    example { call("1  #=> 1", true).should == "1" }
    example { call("1   #=> 1", true).should == "1" }
    example { call("1  #=>  1", true).should == "1" }
    example { call("\n1 # => 1", true).should == "\n1" }
  end

  context 'when told not to clean out value annotations' do
    example { call("1#=>1", false).should == "1#=>1" }
    example { call("1 #=>1", false).should == "1 #=>1" }
    example { call("1  #=>1", false).should == "1  #=>1" }
    example { call("1  #=> 1", false).should == "1  #=> 1" }
    example { call("1   #=> 1", false).should == "1   #=> 1" }
    example { call("1  #=>  1", false).should == "1  #=>  1" }
    example { call("\n1 # => 1", false).should == "\n1 # => 1" }
  end

  context 'cleaning inline exception annotations' do
    example { call("1#~>1").should == "1" }
    example { call("1 #~>1").should == "1" }
    example { call("1  #~>1").should == "1" }
    example { call("1  #~> 1").should == "1" }
    example { call("1   #~> 1").should == "1" }
    example { call("1  #~>  1").should == "1" }
    example { call("\n1 # ~> 1").should == "\n1" }

    example { call("# >> 1").should == "" }
    example { call("# !> 1").should == "" }
  end

  context 'cleaning stdout annotations' do
    example { call(<<-CODE).should == "1" }
    1
    # >> 2
    CODE

    example { call(<<-CODE).should == "1" }
    1

    # >> 2
    CODE

    example { call(<<-CODE).should == "1\n" }
    1


    # >> 2
    CODE

    example { call(<<-CODE).should == "1\n" }
    1


      # >> 2
    # >> 2
     # >> 2
    CODE


    example { call(<<-CODE).should == "1\n" }
    1


    # >> 2
    # >> 3
    CODE
  end

  context 'cleaning stderr annotations' do
    example { call(<<-CODE).should == "1" }
    1
    # !> 2
    CODE

    example { call(<<-CODE).should == "1" }
    1

    # !> 2
    CODE

    example { call(<<-CODE).should == "1" }
    1

    # !> 2
    # !> 3
    CODE

    example { call(<<-CODE).should == "1\n" }
    1


      # !> 2
    # !> 2
     # !> 2
    CODE
  end


  context 'cleaning end of file exception annotations' do
    example { call(<<-CODE).should == "1" }
    1
    # ~>2
    CODE

    example { call(<<-CODE).should == "1" }
    1

    # ~> 2
    CODE

    example { call(<<-CODE).should == "1" }
    1

    # ~> 2
    # ~> 3
    CODE

    example { call(<<-CODE).should == "1\n" }
    1


      # ~> 2
    # ~> 2
     # ~> 2
    CODE

    example { call(<<-CODE).should == "1\n" }
    1 # ~> error


      # ~> error again
    CODE
  end

  context 'putting it all together' do
    example { call(<<-CODE).should == "1" }
    1

    # >> 1
    # >> 2

    # !> 3
    # !> 4

    # ~> 5
    # ~> 6
    CODE

    example { call(<<-CODE).should == "1" }
    1

    # >> 1

    # >> 2

    # !> 3

    # !> 4

    # ~> 5

    # ~> 6
    CODE

    example { call(<<-CODE).should == "1" }
    1

    # >> 1
    # >> 2
    # !> 3
    # !> 4
    # ~> 5
    # ~> 6
    CODE

    example { call(<<-CODE).should == "1\n3" }
    1
    # >> 1
    # >> 2
    3
    # !> 4
    # !> 5
    CODE

    example { call(<<-CODE).should == "1\n3\n6" }
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

    example('', t:true) { call(<<-CODE).should == "1\n\nputs \"omg\"" }
    1  # => 1

    puts "omg"  # ~> RuntimeError: omg

    # ~> RuntimeError
    CODE
  end
end
