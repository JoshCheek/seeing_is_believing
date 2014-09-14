# A BUNCH OF IDEAS ABOUT HOW TO MASS THE STRING THROUGH:

# lambda is to make sure I don't leak vars
lambda {
  initial = (0...128).map(&:chr).join('') << "Ω≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"  # => "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"


  # THE WINNER!
  # uses only code available in core
  # super easy to parse it's a single token, just grab chars until the space
  # doesn't rely on me not fucking up the encoding/decoding like the solution below
  # gets all the weird edge cases correct
  marshaled_and_packed_result = Marshal.load(     # => Marshal
    ( marshaled_and_packed_intermediate =
      [ Marshal.dump(                             # => Marshal
          initial.dup                             # => "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"
        )                                         # => "\x04\bI\"\x01\xDF\x00\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\e\x1C\x1D\x1E\x1F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7F\xCE\xA9\xE2\x89\x88\xC3\xA7\xE2\x88\x9A\xE2\x88\xAB\xCB\x9C\xC2\xB5\xE2\x89\xA4\xE2\x89\xA5\xC3\xA5\xC3\x9F\xE2\x88\x82\xC6\x92\xC2\xA9\xCB\x99\xE2\x88\x86\xCB...
      ].pack('m0')                                # => "BAhJIgHfAAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn/OqeKJiMOn4oia4oiry5zCteKJpOKJpcOlw5/iiILGksKpy5niiIbLmsKs4oCmw6bFk+KIkcK0wq7igKDCpcKoy4bDuM+A4oCc4oCYwqHihKLCo8KiwqrCuuKAmeKAnQY6BkVU"

      marshaled_and_packed_intermediate           # => "BAhJIgHfAAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn/OqeKJiMOn4oia4oiry5zCteKJpOKJpcOlw5/iiILGksKpy5niiIbLmsKs4oCmw6bFk+KIkcK0wq7igKDCpcKoy4bDuM+A4oCc4oCYwqHihKLCo8KiwqrCuuKAmeKAnQY6BkVU"
       .unpack('m0')                              # => ["\x04\bI\"\x01\xDF\x00\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\e\x1C\x1D\x1E\x1F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7F\xCE\xA9\xE2\x89\x88\xC3\xA7\xE2\x88\x9A\xE2\x88\xAB\xCB\x9C\xC2\xB5\xE2\x89\xA4\xE2\x89\xA5\xC3\xA5\xC3\x9F\xE2\x88\x82\xC6\x92\xC2\xA9\xCB\x99\xE2\x88\x86\xC...
       .first                                     # => "\x04\bI\"\x01\xDF\x00\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\e\x1C\x1D\x1E\x1F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7F\xCE\xA9\xE2\x89\x88\xC3\xA7\xE2\x88\x9A\xE2\x88\xAB\xCB\x9C\xC2\xB5\xE2\x89\xA4\xE2\x89\xA5\xC3\xA5\xC3\x9F\xE2\x88\x82\xC6\x92\xC2\xA9\xCB\x99\xE2\x88\x86\xCB...
    )                                             # => "\x04\bI\"\x01\xDF\x00\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\e\x1C\x1D\x1E\x1F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7F\xCE\xA9\xE2\x89\x88\xC3\xA7\xE2\x88\x9A\xE2\x88\xAB\xCB\x9C\xC2\xB5\xE2\x89\xA4\xE2\x89\xA5\xC3\xA5\xC3\x9F\xE2\x88\x82\xC6\x92\xC2\xA9\xCB\x99\xE2\x88\x86\xCB...
  )                                               # => "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"

  marshaled_and_packed_result == initial          # => true
  marshaled_and_packed_intermediate.include? ' '  # => false

  # downside: it's totall illegible
  Marshal.load(                            # => Marshal
    [Marshal.dump("this is the message")]  # => ["\x04\bI\"\x18this is the message\x06:\x06ET"]
      .pack('m0')                          # => "BAhJIhh0aGlzIGlzIHRoZSBtZXNzYWdlBjoGRVQ="
      .unpack('m0')                        # => ["\x04\bI\"\x18this is the message\x06:\x06ET"]
      .first                               # => "\x04\bI\"\x18this is the message\x06:\x06ET"
  )                                        # => "this is the message"




  # THE PROBLEM WITH MARSHAL IS THAT BINARY DATA HAS CHARS I'M USING AS DELIMITERS
  marshal_result = Marshal.load(  # => Marshal
    Marshal.dump(                 # => Marshal
      initial.dup                 # => "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"
    )                             # => "\x04\bI\"\x01\xDF\x00\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\e\x1C\x1D\x1E\x1F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7F\xCE\xA9\xE2\x89\x88\xC3\xA7\xE2\x88\x9A\xE2\x88\xAB\xCB\x9C\xC2\xB5\xE2\x89\xA4\xE2\x89\xA5\xC3\xA5\xC3\x9F\xE2\x88\x82\xC6\x92\xC2\xA9\xCB\x99\xE2\x88\x86\xCB...
  )                               # => "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"
  marshal_result == initial       # => true

  # THE PROBLEM WITH BASE64 ENCODING IS IT LOSES THE UNICODE CHARS
  pack_result =
    [initial.dup]                 # => ["\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"]
      .pack('m0')                 # => "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn/OqeKJiMOn4oia4oiry5zCteKJpOKJpcOlw5/iiILGksKpy5niiIbLmsKs4oCmw6bFk+KIkcK0wq7igKDCpcKoy4bDuM+A4oCc4oCYwqHihKLCo8KiwqrCuuKAmeKAnQ=="
      .unpack('m0')               # => ["\x00\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\e\x1C\x1D\x1E\x1F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7F\xCE\xA9\xE2\x89\x88\xC3\xA7\xE2\x88\x9A\xE2\x88\xAB\xCB\x9C\xC2\xB5\xE2\x89\xA4\xE2\x89\xA5\xC3\xA5\xC3\x9F\xE2\x88\x82\xC6\x92\xC2\xA9\xCB\x99\xE2\x88\x86\xCB\x9A\xC2\xAC\xE2...
      .first                      # => "\x00\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\e\x1C\x1D\x1E\x1F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7F\xCE\xA9\xE2\x89\x88\xC3\xA7\xE2\x88\x9A\xE2\x88\xAB\xCB\x9C\xC2\xB5\xE2\x89\xA4\xE2\x89\xA5\xC3\xA5\xC3\x9F\xE2\x88\x82\xC6\x92\xC2\xA9\xCB\x99\xE2\x88\x86\xCB\x9A\xC2\xAC\xE2\...

  pack_result == initial                         # => false

  "\u0000" == "\x00"                             # => true
  pack_chars    = pack_result.chars              # => ["\x00", "\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\a", "\b", "\t", "\n", "\v", "\f", "\r", "\x0E", "\x0F", "\x10", "\x11", "\x12", "\x13", "\x14", "\x15", "\x16", "\x17", "\x18", "\x19", "\x1A", "\e", "\x1C", "\x1D", "\x1E", "\x1F", " ", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", ...
  initial_chars = initial.chars                  # => ["\u0000", "\u0001", "\u0002", "\u0003", "\u0004", "\u0005", "\u0006", "\a", "\b", "\t", "\n", "\v", "\f", "\r", "\u000E", "\u000F", "\u0010", "\u0011", "\u0012", "\u0013", "\u0014", "\u0015", "\u0016", "\u0017", "\u0018", "\u0019", "\u001A", "\e", "\u001C", "\u001D", "\u001E", "\u001F", " ", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", "0", "1", "2", "3", "4...
  index         = 0                              # => 0
  while pack_chars.first == initial_chars.first  # => true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, tr...
    pack_chars.shift                             # => "\x00", "\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\a", "\b", "\t", "\n", "\v", "\f", "\r", "\x0E", "\x0F", "\x10", "\x11", "\x12", "\x13", "\x14", "\x15", "\x16", "\x17", "\x18", "\x19", "\x1A", "\e", "\x1C", "\x1D", "\x1E", "\x1F", " ", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", "...
    initial_chars.shift                          # => "\u0000", "\u0001", "\u0002", "\u0003", "\u0004", "\u0005", "\u0006", "\a", "\b", "\t", "\n", "\v", "\f", "\r", "\u000E", "\u000F", "\u0010", "\u0011", "\u0012", "\u0013", "\u0014", "\u0015", "\u0016", "\u0017", "\u0018", "\u0019", "\u001A", "\e", "\u001C", "\u001D", "\u001E", "\u001F", " ", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", "0", "1", "2", "3", "4"...
    index += 1                                   # => 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, ...
  end                                            # => nil

  index                # => 128
  pack_chars.first     # => "\xCE"
  initial_chars.first  # => "Ω"

  # JSON, AGAIN CAN'T TELL WHERE MY END IS
  # I could switch such that the entire message is in JSON, but I need the ability to have extra crap after it
  # It looks like it will tell me the char where it becomes invalid, which I could use, but seems like a lot of overhead to parse 2x
  # and it brings in this lib, which might have namespace overlap w/ some other lib, or get modified by some other JSON lib, since stdlib one is so annoying
  # so I'm not sure how much I can rely on it actually working
  require 'json'                                  # => false
  json_result = JSON.load(                        # => JSON
    JSON.dump(                                    # => JSON
      initial.dup                                 # => "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"
    )                                             # => "\"\\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\b\\t\\n\\u000b\\f\\r\\u000e\\u000f\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017\\u0018\\u0019\\u001a\\u001b\\u001c\\u001d\\u001e\\u001f !\\\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”\""
  )                                               # => "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"
  json_result == initial                          # => true


  # TRY GOING THROUGH BYTE ARRAY INSTEAD -- NOT ANY MORE LEGIBLE THAN MARSHAL, AND MORE LIKELY TO FUCK SOMETHING UP SOMEWHERE
  initial.encoding                         # => #<Encoding:UTF-8>
  initial.bytes                            # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 1...
    .pack('c*')                            # => "\x00\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\e\x1C\x1D\x1E\x1F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7F\xCE\xA9\xE2\x89\x88\xC3\xA7\xE2\x88\x9A\xE2\x88\xAB\xCB\x9C\xC2\xB5\xE2\x89\xA4\xE2\x89\xA5\xC3\xA5\xC3\x9F\xE2\x88\x82\xC6\x92\xC2\xA9\xCB\x99\xE2\x88\x86\xCB\x9A\xC2\xAC\xE2\...
    .force_encoding('utf-8') ==            # => "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"
    initial                                # => true

  ["abc √".bytes                # => [97, 98, 99, 32, 226, 136, 154]
    .pack('c*')                 # => "abc \xE2\x88\x9A"
  ].pack('m0')                  # => "YWJjIOKImg=="
   .unpack('m0')                # => ["abc \xE2\x88\x9A"]
   .first                       # => "abc \xE2\x88\x9A"
   .force_encoding('utf-8') ==  # => "abc √"
    'abc √'                     # => true

}.call  # => true



# THERE IS ALSO THIS ABSURD ATTEMPT TO WRITE MY OWN SHITTY INSPECT/UNINSPECT

# try transferring with my own shitty escaping/unescaping
ESCAPED_CHAR_MAP = Hash.[] (0..127).map { |c|  # => 0..127
  [c.chr.inspect[1...-1], c.chr]               # => ["\\x00", "\x00"], ["\\x01", "\x01"], ["\\x02", "\x02"], ["\\x03", "\x03"], ["\\x04", "\x04"], ["\\x05", "\x05"], ["\\x06", "\x06"], ["\\a", "\a"], ["\\b", "\b"], ["\\t", "\t"], ["\\n", "\n"], ["\\v", "\v"], ["\\f", "\f"], ["\\r", "\r"], ["\\x0E", "\x0E"], ["\\x0F", "\x0F"], ["\\x10", "\x10"], ["\\x11", "\x11"], ["\\x12", "\x12"], ["\\x13", "\x13"], ["\\x14", "\x14"], ["\\x15", "\x15"], ["...
}                                              # => {"\\x00"=>"\x00", "\\x01"=>"\x01", "\\x02"=>"\x02", "\\x03"=>"\x03", "\\x04"=>"\x04", "\\x05"=>"\x05", "\\x06"=>"\x06", "\\a"=>"\a", "\\b"=>"\b", "\\t"=>"\t", "\\n"=>"\n", "\\v"=>"\v", "\\f"=>"\f", "\\r"=>"\r", "\\x0E"=>"\x0E", "\\x0F"=>"\x0F", "\\x10"=>"\x10", "\\x11"=>"\x11", "\\x12"=>"\x12", "\\x13"=>"\x13", "\\x14"=>"\x14", "\\x15"=>"\x15", "\\x16"=>"\x16", "\\x17"=>"\x17", "\\x18"=>"\...

def safe_string(string)
  string = string.dup       # => "a\n\"b\u0001c∑d"
  string.gsub! "\n", "\\n"  # => "a\\n\"b\u0001c∑d"
  string.gsub! '"', '\"'    # => "a\\n\\\"b\u0001c∑d"
  %'"#{string}"'            # => "\"a\\n\\\"b\u0001c∑d\""
end

def extract_string(line)
  chars = line.chars            # => ["\"", "a", "\\", "n", "\\", "\"", "b", "\u0001", "c", "∑", "d", "\"", "r", "e", "m", "a", "i", "n", "d", "e", "r"]
  chars.shift                   # => "\""
  extracted = ""                # => ""
  loop do
    if chars[0] == '"'          # => false, false, false, false, false, false, false, false, true
      chars.shift               # => "\""
      break
    elsif chars[0] == '\\'      # => false, true, true, false, false, false, false, false
      extracted <<              # => "a", "a\n"
        ESCAPED_CHAR_MAP[       # => {"\\x00"=>"\x00", "\\x01"=>"\x01", "\\x02"=>"\x02", "\\x03"=>"\x03", "\\x04"=>"\x04", "\\x05"=>"\x05", "\\x06"=>"\x06", "\\a"=>"\a", "\\b"=>"\b", "\\t"=>"\t", "\\n"=>"\n", "\\v"=>"\v", "\\f"=>"\f", "\\r"=>"\r", "\\x0E"=>"\x0E", "\\x0F"=>"\x0F", "\\x10"=>"\x10", "\\x11"=>"\x11", "\\x12"=>"\x12", "\\x13"=>"\x13", "\\x14"=>"\x14", "\\x15"=>"\x15", "\\x16"=>"\x16", "\\x17"=>"\x17", "\\x18"=>"\...
          chars.shift<<         # => "\\", "\\"
          chars.shift           # => "\\n", "\\\""
        ]                       # => "a\n", "a\n\""
    elsif chars[0] == '"'       # => false, false, false, false, false, false
      extracted << chars.shift
      break
    else
      extracted                 # => "", "a\n\"", "a\n\"b", "a\n\"b\u0001", "a\n\"b\u0001c", "a\n\"b\u0001c∑"
      extracted << chars.shift  # => "a", "a\n\"b", "a\n\"b\u0001", "a\n\"b\u0001c", "a\n\"b\u0001c∑", "a\n\"b\u0001c∑d"
    end
  end                           # => nil
  line.replace chars.join('')   # => "remainder"
  extracted                     # => "a\n\"b\u0001c∑d"
end

initial   = "a\n\"b\x01c∑d"                 # => "a\n\"b\u0001c∑d"
puts "INITIAL:       #{initial.inspect}"    # => nil
safe      = safe_string(initial)            # => "\"a\\n\\\"b\u0001c∑d\""
puts "SAFE:          #{safe.inspect}"       # => nil
safe     += 'remainder'                     # => "\"a\\n\\\"b\u0001c∑d\"remainder"
puts "WITHOTHAHSHIZ: #{safe.inspect}"       # => nil
extracted = extract_string(safe)            # => "a\n\"b\u0001c∑d"
puts "EXTRACTED:     #{extracted.inspect}"  # => nil
puts "REMAINING:     #{safe.inspect}"       # => nil

initial == extracted  # => true

# Works for that one, but can't deal with the initial from up above,
# I'd have to parse these fancy \u and \x things
(0...128).map(&:chr).join('') << "Ω≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"  # => "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\a\b\t\n\v\f\r\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\e\u001C\u001D\u001E\u001F !\"\#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\u007FΩ≈ç√∫˜µ≤≥åß∂ƒ©˙∆˚¬…æœ∑´®†¥¨ˆøπ“‘¡™£¢ªº’”"


# >> INITIAL:       "a\n\"b\u0001c∑d"
# >> SAFE:          "\"a\\n\\\"b\u0001c∑d\""
# >> WITHOTHAHSHIZ: "\"a\\n\\\"b\u0001c∑d\"remainder"
# >> EXTRACTED:     "a\n\"b\u0001c∑d"
# >> REMAINING:     "remainder"

