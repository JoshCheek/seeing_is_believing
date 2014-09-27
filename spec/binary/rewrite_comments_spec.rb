require 'spec_helper'
require 'seeing_is_believing/binary/rewrite_comments'

RSpec.describe SeeingIsBelieving::Binary::RewriteComments do
  def call(code, options={}, &block)
    described_class.call code, options, &block
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

  it 'can be given additional lines to make sure are provided, whether they have comments on them or not' do
    rewritten = call("'a'\n"\
                     "'b'\n"\
                     "'c' # c\n"\
                     "'d'",
                     always_rewrite: [2, 3]) do |c|
                       value = sprintf "%d|%d|%p|%d|%p|%d..%d|%d..%d|%d..%d",
                                       c.line_number,
                                       c.whitespace_col,
                                       c.whitespace,
                                       c.text_col,
                                       c.text,
                                       c.full_range.begin_pos,
                                       c.full_range.end_pos,
                                       c.whitespace_range.begin_pos,
                                       c.whitespace_range.end_pos,
                                       c.comment_range.begin_pos,
                                       c.comment_range.end_pos
                       ['pre', value]
                     end
    expect(rewritten).to eq \
      "'a'\n"\
      "'b'pre2|3|\"\"|3|\"\"|7..7|7..7|7..7\n"\
      "'c'pre3|3|\" \"|4|\"# c\"|11..15|11..12|12..15\n"\
      "'d'"

    rewritten = call("", always_rewrite: [1]) { |c| ['a', 'b'] }
    expect(rewritten).to eq "ab"

    rewritten = call("a", always_rewrite: [1]) { |c| ['b', 'c'] }
    expect(rewritten).to eq "abc"

    rewritten = call("a\n", always_rewrite: [1]) { |c| ['b', 'c'] }
    expect(rewritten).to eq "abc\n"
  end
end
