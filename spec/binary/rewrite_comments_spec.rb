require 'spec_helper'
require 'seeing_is_believing/binary/rewrite_comments'

RSpec.describe SeeingIsBelieving::Binary::RewriteComments do
  def call(code, &block)
    described_class.call code, &block
  end

  it 'ignores multiline comments' do
    seen = []
    call("123\n=begin\n456\n=end\n789") do |*args|
      seen << args
      args[-2..-1]
    end
    expect(seen).to eq []
  end

  it 'yields the Code::InlineComment' do
    seen = []
    call("# c1\n"\
         "123 #   c2 # x\n"\
         "n456\n"\
         " \t # c3\n"\
         "%Q{\n"\
         " 1}#c4\n"\
         "# c5") do |comment|
      seen << comment
      ['', '']
    end
    expect(seen.map(&:text)).to eq [
      "# c1",
      "#   c2 # x",
      "# c3",
      "#c4",
      "# c5",
    ]
  end

  it 'rewrites the whitespace and comment with the whitespace and comment that are returned' do
    rewritten = call("# c1\n"\
                     "123 #c2\n"\
                     "n456\n"\
                     " \t # c3\n"\
                     "%Q{\n"\
                     " 1}#c4") do |c|
      ["NEW_WHITESPACE#{c.line_number}", "--COMMENT-#{c.line_number}--"]
    end
    expect(rewritten).to eq "NEW_WHITESPACE1--COMMENT-1--\n"\
                            "123NEW_WHITESPACE2--COMMENT-2--\n"\
                            "n456\n"\
                            "NEW_WHITESPACE4--COMMENT-4--\n"\
                            "%Q{\n"\
                            " 1}NEW_WHITESPACE6--COMMENT-6--"
  end
end
