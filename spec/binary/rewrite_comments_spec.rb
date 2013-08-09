require 'seeing_is_believing/binary/rewrite_comments'

describe SeeingIsBelieving::Binary::RewriteComments do
  def call(code, &block)
    described_class.call code, &block
  end

  it 'ignores multiline comments' do
    seen = []
    call("123\n=begin\n456\n=end\n789") do |*args|
      seen << args
      args[-2..-1]
    end
    seen.should == []
  end

  it 'yields the line_number, line upto the whitespace, whitespace, and comment' do
    seen = []
    call("# c1\n"\
         "123 #   c2 # x\n"\
         "n456\n"\
         " \t # c3\n"\
         "%Q{\n"\
         " 1}#c4\n"\
         "# c5") do |*args|
      seen << args
      args[-2..-1]
    end
    seen.should == [
      [1,  "",     "",      "# c1"],
      [2,  "123",  " ",     "#   c2 # x"],
      [4,  "",     " \t ",  "# c3"],
      [6,  " 1}",  "",      "#c4"],
      [7,  "",    "",      "# c5"],
    ]
  end

  it 'rewrites the whitespace and comment with the whitespace and comment that are returned' do
    rewritten = call("# c1\n"\
                     "123 #c2\n"\
                     "n456\n"\
                     " \t # c3\n"\
                     "%Q{\n"\
                     " 1}#c4") do |line_number, *|
      ["NEW_WHITESPACE#{line_number}", "--COMMENT-#{line_number}--"]
    end
    rewritten.should == "NEW_WHITESPACE1--COMMENT-1--\n"\
                        "123NEW_WHITESPACE2--COMMENT-2--\n"\
                        "n456\n"\
                        "NEW_WHITESPACE4--COMMENT-4--\n"\
                        "%Q{\n"\
                        " 1}NEW_WHITESPACE6--COMMENT-6--"
  end
end
