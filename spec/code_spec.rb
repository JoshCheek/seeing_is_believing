require 'seeing_is_believing/code'

RSpec.describe SeeingIsBelieving::Code do
  def code_for(raw_code, options={})
    manage_newline = options.fetch :nl, true
    raw_code += "\n" if manage_newline && !raw_code.end_with?("\n")
    described_class.new(raw_code)
  end

  def assert_range(range, begin_pos, end_pos)
    expect(range.begin_pos).to eq begin_pos
    expect(range.end_pos).to eq end_pos
  end

  it 'raises a SyntaxError if given a file that does not end in a newline' do
    code_for "\n", nl: false
    expect { code_for "", nl: false  }.to raise_error SyntaxError, /newline/i

    code_for "1\n", nl: false
    expect { code_for "1", nl: false }.to raise_error SyntaxError, /newline/i
  end

  describe '#range_for' do
    it 'returns a range object with the specified start and ends' do
      code  = code_for "abcd"
      range = code.range_for(1, 2)
      expect(range.begin_pos).to eq 1
      expect(range.end_pos).to eq 2
      expect(range.source).to eq 'b'
    end
  end

  describe '#root' do
    it 'returns the root for valid code' do
      expect(code_for('1').root.type).to eq :int
    end
    it 'returns a null root for invalid code' do
      root = code_for('"').root
      expect(root.type).to eq :null_node
      assert_range root.location.expression, 0, 0
    end
    it 'returns a null root for empty code' do
      root = code_for('').root
      expect(root.type).to eq :null_node
      assert_range root.location.expression, 0, 0
    end
  end

  describe '#index_to_linenum' do
    it 'treats indexes as 0based and lines as 1based' do
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

    it 'considers any indexes after the end to be on the last line' do
      expect(code_for("a\nb\nc\n").index_to_linenum(1000)).to eq 4
    end
  end

  describe '#linenum_to_index' do
    it 'treats line numebrs as 1based and indexes as 0based' do
      code = code_for "xx\nyyy\n\nzz\n"
      expect(code.linenum_to_index 1).to eq 0
      expect(code.linenum_to_index 2).to eq 3
      expect(code.linenum_to_index 3).to eq 7
      expect(code.linenum_to_index 4).to eq 8
      expect(code.linenum_to_index 5).to eq 11
    end

    it 'considers any lines past the end to be at 1 character after the last index' do
      expect(code_for("abc\n").linenum_to_index(100)).to eq 4
    end
  end

  # should it begin after magic comments and stuff?
  describe '#body_range' do
    it 'returns a range for the whole body' do
      assert_range code_for("\n").body_range, 0, 1
      assert_range code_for("1\n").body_range, 0, 2
      assert_range code_for("1111\n").body_range, 0, 5
    end

    it 'ends after the last token prior to __END__ statements' do
      assert_range code_for("__END__\n").body_range, 0, 0
      assert_range code_for("\n__END__\n").body_range, 0, 1
      assert_range code_for("a\n__END__\n").body_range, 0, 2
      assert_range code_for("a\n\n\n__END__\n").body_range, 0, 2
    end

    it 'ends after trailing comments' do
      assert_range code_for("1#a\n").body_range, 0, 4
      assert_range code_for("1#a\n#b\n#c\n").body_range, 0, 10
      assert_range code_for("1#a\n#b\n#c\n\n").body_range, 0, 10
      assert_range code_for("a\n#c\n\n__END__\n").body_range, 0, 5
      assert_range code_for("1#a\n#b\n#c\n__END__\n").body_range, 0, 10
      assert_range code_for("1#a\n#b\n#c\n\n__END__\n").body_range, 0, 10
    end

    it 'ends after heredocs' do
      assert_range code_for("<<a\nb\na\n").body_range, 0, 8
      assert_range code_for("<<a\nb\na\n1\n").body_range, 0, 10
      assert_range code_for("<<a\nb\na\n#c\n").body_range, 0, 11
    end
  end

  describe 'void value expressions' do
    def void_value?(ast)
      code_for("\n").void_value?(ast)
    end

    def ast_for(code)
      Parser::CurrentRuby.parse code
    end

    it 'knows a `return`, `next`, `redo`, `retry`, and `break` are void values' do
      expect(void_value?(ast_for("def a; return; end").children.last)).to be true
      expect(void_value?(ast_for("loop { next  }"    ).children.last)).to be true
      expect(void_value?(ast_for("loop { redo  }"    ).children.last)).to be true
      expect(void_value?(ast_for("loop { break }"    ).children.last)).to be true

      the_retry = ast_for("begin; rescue; retry; end").children.first.children[1].children.last
      expect(the_retry.type).to eq :retry
      expect(void_value? the_retry).to eq true
    end
    it 'knows an `if` is a void value if either side is a void value' do
      the_if = ast_for("def a; if 1; return 2; else; 3; end; end").children.last
      expect(the_if.type).to eq :if
      expect(void_value?(the_if)).to be true

      the_if = ast_for("def a; if 1; 2; else; return 3; end; end").children.last
      expect(the_if.type).to eq :if
      expect(void_value?(the_if)).to be true

      the_if = ast_for("def a; if 1; 2; else; 3; end; end").children.last
      expect(the_if.type).to eq :if
      expect(void_value?(the_if)).to be false
    end
    it 'knows a begin is a void value if its last element is a void value' do
      the_begin = ast_for("loop { begin; break; end }").children.last
      expect([:begin, :kwbegin]).to include the_begin.type
      expect(void_value?(the_begin)).to be true

      the_begin = ast_for("loop { begin; 1; end }").children.last
      expect([:begin, :kwbegin]).to include the_begin.type
      expect(void_value?(the_begin)).to be false
    end
    it 'knows a rescue is a void value if its last child or its else is a void value' do
      the_rescue = ast_for("begin; rescue; retry; end").children.first
      expect(the_rescue.type).to eq :rescue
      expect(void_value?(the_rescue)).to be true

      the_rescue = ast_for("begin; rescue; 1; else; retry; end").children.first
      expect(the_rescue.type).to eq :rescue
      expect(void_value?(the_rescue)).to be true

      the_rescue = ast_for("begin; rescue; 1; else; 2; end").children.first
      expect(the_rescue.type).to eq :rescue
      expect(void_value?(the_rescue)).to be false
    end
    it 'knows an ensure is a void value if its body or ensure portion are void values' do
      the_ensure = ast_for("loop { begin; break; ensure; 1; end }").children.last.children.last
      expect(the_ensure.type).to eq :ensure
      expect(void_value?(the_ensure)).to be true

      the_ensure = ast_for("loop { begin; 1; ensure; break; end }").children.last.children.last
      expect(the_ensure.type).to eq :ensure
      expect(void_value?(the_ensure)).to be true

      the_ensure = ast_for("loop { begin; 1; ensure; 2; end }").children.last.children.last
      expect(the_ensure.type).to eq :ensure
      expect(void_value?(the_ensure)).to be false
    end
    it 'knows other things are not void values' do
      expect(void_value?(ast_for "123")).to be false
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
