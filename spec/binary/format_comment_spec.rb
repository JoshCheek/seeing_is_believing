# encoding: utf-8

require 'spec_helper'
require 'seeing_is_believing/binary/format_comment'

RSpec.describe SeeingIsBelieving::Binary::FormatComment do
  def result_for(line_length, separator, result, options={})
    described_class.new(line_length, separator, result, options).call
  end

  specify 'it returns the consolidated result if there are no truncations' do
    expect(result_for 1, '=>', '12345').to eq '=>12345'
  end

  specify 'max_result_length truncates a result to the specified length, using elipses up to that length if appropriate'  do
    line_length = 1
    separator   = '=>'
    result      = '12345'
    expect(result_for line_length,   separator, result, max_result_length: Float::INFINITY).to eq '=>12345'
    expect(result_for line_length,   separator, result, max_result_length: 7              ).to eq '=>12345'
    expect(result_for line_length,   separator, result, max_result_length: 6              ).to eq '=>1...'
    expect(result_for line_length+1, separator, result, max_result_length: 6              ).to eq '=>1...'
    expect(result_for line_length,   separator, result, max_result_length: 5              ).to eq '=>...'
    expect(result_for line_length,   separator, result, max_result_length: 4              ).to eq ''
    expect(result_for line_length,   separator, result, max_result_length: 0              ).to eq ''
  end

  specify 'max_line_length truncates a result to the specified length, minus the length of the line' do
    line_length = 1
    separator   = '=>'
    result      = '12345'
    expect(result_for line_length,   separator, result                                  ).to eq '=>12345'
    expect(result_for line_length,   separator, result, max_line_length: Float::INFINITY).to eq '=>12345'
    expect(result_for line_length,   separator, result, max_line_length: 8              ).to eq '=>12345'
    expect(result_for line_length,   separator, result, max_line_length: 7              ).to eq '=>1...'
    expect(result_for line_length+1, separator, result, max_line_length: 7              ).to eq '=>...'
    expect(result_for line_length,   separator, result, max_line_length: 6              ).to eq '=>...'
    expect(result_for line_length,   separator, result, max_line_length: 5              ).to eq ''
    expect(result_for line_length,   separator, result, max_line_length: 0              ).to eq ''
  end

  specify 'pad_to will pad the length that the line is displayed in' do
    expect(result_for 1, '=>', '2', pad_to: 0).to eq '=>2'
    expect(result_for 1, '=>', '2', pad_to: 1).to eq '=>2'
    expect(result_for 1, '=>', '2', pad_to: 2).to eq ' =>2'
    expect(result_for 2, '=>', '2', pad_to: 2).to eq '=>2'
  end

  specify 'pad_to is ignored when separator/result will not be printed' do
    expect(result_for 1, '=>', '12345', pad_to: 2,   max_line_length: 2).to eq ''
    expect(result_for 1, '=>', '12345', pad_to: 2, max_result_length: 2).to eq ''
  end

  specify 'they can all work together' do
    expect(result_for 1, '=>', '12345', max_line_length: 100, max_result_length: 100, pad_to: 2).to eq ' =>12345'
    expect(result_for 1, '=>', '12345', max_line_length:   8, max_result_length: 100, pad_to: 2).to eq ' =>1...'
    expect(result_for 1, '=>', '12345', max_line_length: 100, max_result_length:   6, pad_to: 2).to eq ' =>1...'
    expect(result_for 1, '=>', '12345', max_line_length: 100, max_result_length:   6, pad_to: 2).to eq ' =>1...'
  end

  def assert_printed(c, printed)
    c = c.force_encoding 'utf-8'
    result = result_for 0, '', c
    expect(result).to eq printed
    expect(result.encoding).to eq Encoding::UTF_8
    expect(result).to be_valid_encoding
  end

  it 'escapes any non-printable characters' do
    assert_printed     '©' , '©'
    assert_printed   0.chr , "\\u0000"
    assert_printed   1.chr , "\\u0001"
    assert_printed   2.chr , "\\u0002"
    assert_printed   3.chr , "\\u0003"
    assert_printed   4.chr , "\\u0004"
    assert_printed   5.chr , "\\u0005"
    assert_printed   6.chr , "\\u0006"
    assert_printed   7.chr , "\\a"
    assert_printed   8.chr , "\\b"
    assert_printed   9.chr , "\\t"
    assert_printed  10.chr , "\\n"
    assert_printed  11.chr , "\\v"
    assert_printed  12.chr , "\\f"
    assert_printed  13.chr , "\\r"
    assert_printed  14.chr , "\\u000E"
    assert_printed  15.chr , "\\u000F"
    assert_printed  16.chr , "\\u0010"
    assert_printed  17.chr , "\\u0011"
    assert_printed  18.chr , "\\u0012"
    assert_printed  19.chr , "\\u0013"
    assert_printed  20.chr , "\\u0014"
    assert_printed  21.chr , "\\u0015"
    assert_printed  22.chr , "\\u0016"
    assert_printed  23.chr , "\\u0017"
    assert_printed  24.chr , "\\u0018"
    assert_printed  25.chr , "\\u0019"
    assert_printed  26.chr , "\\u001A"
    assert_printed  27.chr , "\\e"
    assert_printed  28.chr , "\\u001C"
    assert_printed  29.chr , "\\u001D"
    assert_printed  30.chr , "\\u001E"
    assert_printed  31.chr , "\\u001F"
    assert_printed  32.chr , " "
    assert_printed  33.chr , "!"
    assert_printed  34.chr , '"' # printable, thus not escaped
    assert_printed  35.chr , "#"
    assert_printed  36.chr , "$"
    assert_printed  37.chr , "%"
    assert_printed  38.chr , "&"
    assert_printed  39.chr , "'"
    assert_printed  40.chr , "("
    assert_printed  41.chr , ")"
    assert_printed  42.chr , "*"
    assert_printed  43.chr , "+"
    assert_printed  44.chr , ","
    assert_printed  45.chr , "-"
    assert_printed  46.chr , "."
    assert_printed  47.chr , "/"
    assert_printed  48.chr , "0"
    assert_printed  49.chr , "1"
    assert_printed  50.chr , "2"
    assert_printed  51.chr , "3"
    assert_printed  52.chr , "4"
    assert_printed  53.chr , "5"
    assert_printed  54.chr , "6"
    assert_printed  55.chr , "7"
    assert_printed  56.chr , "8"
    assert_printed  57.chr , "9"
    assert_printed  58.chr , ":"
    assert_printed  59.chr , ";"
    assert_printed  60.chr , "<"
    assert_printed  61.chr , "="
    assert_printed  62.chr , ">"
    assert_printed  63.chr , "?"
    assert_printed  64.chr , "@"
    assert_printed  65.chr , "A"
    assert_printed  66.chr , "B"
    assert_printed  67.chr , "C"
    assert_printed  68.chr , "D"
    assert_printed  69.chr , "E"
    assert_printed  70.chr , "F"
    assert_printed  71.chr , "G"
    assert_printed  72.chr , "H"
    assert_printed  73.chr , "I"
    assert_printed  74.chr , "J"
    assert_printed  75.chr , "K"
    assert_printed  76.chr , "L"
    assert_printed  77.chr , "M"
    assert_printed  78.chr , "N"
    assert_printed  79.chr , "O"
    assert_printed  80.chr , "P"
    assert_printed  81.chr , "Q"
    assert_printed  82.chr , "R"
    assert_printed  83.chr , "S"
    assert_printed  84.chr , "T"
    assert_printed  85.chr , "U"
    assert_printed  86.chr , "V"
    assert_printed  87.chr , "W"
    assert_printed  88.chr , "X"
    assert_printed  89.chr , "Y"
    assert_printed  90.chr , "Z"
    assert_printed  91.chr , "["
    assert_printed  92.chr , "\\" # printable, thus not escaped
    assert_printed  93.chr , "]"
    assert_printed  94.chr , "^"
    assert_printed  95.chr , "_"
    assert_printed  96.chr , "`"
    assert_printed  97.chr , "a"
    assert_printed  98.chr , "b"
    assert_printed  99.chr , "c"
    assert_printed 100.chr , "d"
    assert_printed 101.chr , "e"
    assert_printed 102.chr , "f"
    assert_printed 103.chr , "g"
    assert_printed 104.chr , "h"
    assert_printed 105.chr , "i"
    assert_printed 106.chr , "j"
    assert_printed 107.chr , "k"
    assert_printed 108.chr , "l"
    assert_printed 109.chr , "m"
    assert_printed 110.chr , "n"
    assert_printed 111.chr , "o"
    assert_printed 112.chr , "p"
    assert_printed 113.chr , "q"
    assert_printed 114.chr , "r"
    assert_printed 115.chr , "s"
    assert_printed 116.chr , "t"
    assert_printed 117.chr , "u"
    assert_printed 118.chr , "v"
    assert_printed 119.chr , "w"
    assert_printed 120.chr , "x"
    assert_printed 121.chr , "y"
    assert_printed 122.chr , "z"
    assert_printed 123.chr , "{"
    assert_printed 124.chr , "|"
    assert_printed 125.chr , "}"
    assert_printed 126.chr , "~"
    assert_printed 127.chr, "\u007F"
  end

  it 'can be given a list of characters to not escape' do
    expect(result_for 0, '', "\r\n", dont_escape: ["\n"]).to eq "\\r\n"
    expect(result_for 0, '', "\r\n", dont_escape: ["\r"]).to eq "\r\\n"
  end

  it 'escapes them before running through the other calculations' do
    expect(result_for 1, '=>', "\r\n", max_line_length: 7).to eq '=>\r\n'
    expect(result_for 1, '=>', "\r\n", max_line_length: 6).to eq '=>...'
  end
end
