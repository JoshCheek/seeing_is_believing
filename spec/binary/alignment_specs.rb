# This is mostly tested in the cukes, but some are hard to hit

require 'seeing_is_believing/binary/align_chunk'

RSpec.describe '1-off alignment specs' do
  def chunk(code)
    code << "\n"
    SeeingIsBelieving::Binary::AlignChunk.new code
  end

  describe 'AlignChunk' do
    it 'considers entirely whitespace lines to be a chunk separator' do
      empty_line      = chunk "aaaaa\n\n1"
      whitespace_line = chunk "aaaaa\n   \t   \n1"
      expect(whitespace_line.line_length_for 1).to eq empty_line.line_length_for(1)
      expect(whitespace_line.line_length_for 3).to eq empty_line.line_length_for(3)
    end

    it 'is not fooled by whitespace on the first/last line' do
      expect(chunk("   \na\n   ").line_length_for(2)).to eq 3
    end

    it 'is not fooled by trailing whitespace in general' do
      expect(chunk("a         ").line_length_for(1)).to eq 3
    end
  end
end
