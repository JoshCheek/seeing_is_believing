require 'seeing_is_believing/code'

RSpec.describe SeeingIsBelieving::Code do
  def code_for(raw_code)
    described_class.new(raw_code)
  end

  describe '#range_for' do
    it 'returns a range object with the specified start and ends'
  end

  describe 'index_to_linenum' do
    it 'treats indexes as 0 based and lines as 1based' do
      code = code_for "xx\nyyy\n\nzz"
      [[1,0], [1,1], [1,2],
       [2,3], [2,4], [2,5], [2,6],
       [3,7],
       [4,8], [4,9],
      ].each do |expected_lineno, index|
        actual_lineno = code.index_to_linenum index
        expect(expected_lineno).to eq(actual_lineno),
          "index:           #{index}\n"\
          "expected lineno: #{expected_lineno}\n"\
          "actual lineno:   #{actual_lineno.inspect}"
      end
    end

    it 'raises an IndexError if asked for an index outside its range' do
      code = code_for("aaa")
      # expect { code.index_to_linenum -1 }.to raise_error IndexError # ignoring b/c maybe it makes more sense to look from the end?
      code.index_to_linenum 0
      code.index_to_linenum 1
      code.index_to_linenum 2
      expect { code.index_to_linenum 3 }.to raise_error IndexError

      # when there are no chars
      expect { code_for("").index_to_linenum 0 }.to raise_error IndexError
    end
  end
end



#   describe '#inline_comments' do
#     xit 'finds their line_number, column_number, preceding_whitespace, text, preceding_whitespace_range, and comment_range' do
#       code = code_for <<-CODE.gsub(/^\s*/, '')
#       # c1
#       not c
#       # c2

#       not c
#       =begin
#       mul
#       ti
#       line
#       =end
#       preceding code  \t # c3
#       CODE
#       cs = code.inline_comments
#       expect(cs.map &:line_number         ).to eq [1, 3, 4]
#       expect(cs.map &:column_number       ).to eq [1, 1, 18]
#       expect(cs.map &:preceding_whitespace).to eq ["", "", "  \t "]
#       expect(cs.map &:text                ).to eq ['# c1', '# c2', '# c3']

#       preceding_whitespace_range
#       comment_range

#       expect(code.inline_comments.map &:ra)
#       multilines = code.multiline_comments
#     end

#     it 'finds multiline comments'

#     it 'finds comments in syntactically invalid files'
#   end

#   it 'knows whether a string is a heredoc'
#   it 'knows if the file is syntactically valid'
#   it 'knows whether there is a data segment'
#   it 'knows what line the data segment starts on'
#   it 'knows how many lines there are'
#   it 'provides the ast'
#   it 'provides the ability to rewrite code'
#   it 'provides access to the source with #[]'
# end
