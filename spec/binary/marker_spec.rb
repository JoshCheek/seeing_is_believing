require 'seeing_is_believing/binary/marker'

RSpec.describe SeeingIsBelieving::Binary::Marker do

  describe 'to_regex' do
    def assert_parses(input, regex)
      expect(described_class.to_regex input).to eq regex
    end

    it 'doesn\'t change existing regexes' do
      assert_parses /^.$/ix, /^.$/ix
    end

    it 'converts strings into regexes' do
      assert_parses '',    %r()
      assert_parses 'a',   %r(a)
    end

    it 'ignores surrounding slashes' do
      assert_parses '//',  %r()
      assert_parses '/a/', %r(a)
    end

    it 'respects flags after the trailing slash in surrounding slashes' do
      assert_parses '/a/',     %r(a)
      assert_parses '/a//',    %r(a/)
      assert_parses '//a/',    %r(/a)
      assert_parses '/a/i',    %r(a)i
      assert_parses '/a/im',   %r(a)im
      assert_parses '/a/xim',  %r(a)xim
      assert_parses '/a/mix',  %r(a)mix
      assert_parses '/a/mixi', %r(a)mixi
    end

    it 'isn\'t fooled by strings that kinda look regexy' do
      assert_parses '/a',  %r(/a)
      assert_parses 'a/',  %r(a/)
      assert_parses '/',   %r(/)
      assert_parses '/i',  %r(/i)
    end

    it 'does not escape the content' do
      assert_parses 'a\\s+',   %r(a\s+)
      assert_parses '/a\\s+/', %r(a\s+)
    end
  end

  it 'requires text and a regex' do
    described_class.new text: '', regex: //
    expect { described_class.new }.to raise_error
    expect { described_class.new text: ''  }.to raise_error
    expect { described_class.new regex: // }.to raise_error
  end

  it 'stores the text and a regex' do
    marker = described_class.new(text: 't', regex: /r/)
    expect(marker.text).to eq 't'
    expect(marker.regex).to eq /r/
  end

  it 'converts strings to rgexes when they are set' do
    marker = described_class.new text: 't', regex: "r1"
    expect(marker[:regex]).to eq /r1/

    marker.regex = "/r2/i"
    expect(marker.regex).to eq /r2/i

    marker[:regex] = 'r3'
    expect(marker.regex).to eq /r3/
  end
end
