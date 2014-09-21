# require 'seeing_is_believing/code'

# RSpec.describe 'SeeingIsBelieving::Code' do
#   describe '#range' do
#     it 'returns a range object with the specified start and ends'
#   end

#   describe '#inline_comments' do
#     it 'finds their line_number, column_number, preceding_whitespace, text, preceding_whitespace_range, and comment_range' do
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
