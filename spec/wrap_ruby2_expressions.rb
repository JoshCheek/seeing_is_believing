# doesn't get run directly, rather gets eval'd in wrap_expressions_spec
# if we are on Ruby 2+

it 'respects __dir__ macro' do
  expect(wrap('__dir__')).to eq '<__dir__>'
end

it 'does not wrap keyword/keywordrest arguments' do
  expect(wrap("def a(b,c=1,*d,e:,f:1,**g, &h)\n1\nend"))
    .to eq "<def a(b,c=1,*d,e:,f:1,**g, &h)\n<1>\nend>"
  expect(wrap("def a(*, **)\n1\nend")).to eq "<def a(*, **)\n<1>\nend>"
  expect(wrap("def a b:\n1\nend")).to eq "<def a b:\n<1>\nend>"
  expect(wrap("def a b:\nreturn 1\nend")).to eq "<def a b:\nreturn <1>\nend>"
  expect(wrap("def a b:\nreturn\nend")).to eq "<def a b:\nreturn\nend>"
  expect(wrap("a b:1, **c")).to eq "<a b:1, **c>"
  pending "THIS IS A BUG! (NOTE: THEY ALSO HIT ARRAY SPLATTING)"
  expect(wrap("{\na:1,\n**b\n}")).to eq "<{\na:<1>,\n**<b>\n}>"
  expect(wrap("a(b:1,\n **c\n)")).to eq "<a(b:<1>,\n **<c>\n)>"
end

it 'tags javascript style hashes' do
  expect(wrap(%[{\na:1,\n'b':2,\n"c":3\n}])).to eq %[<{\na:<1>,\n'b':<2>,\n"c":<3>\n}>]
  expect(wrap(%[a b: 1,\n'c': 2,\n"d": 3,\n:e => 4])).to eq %[<a b: <1>,\n'c': <2>,\n"d": <3>,\n:e => 4>]
end

it 'wraps symbol literals' do
  expect(wrap("%i[abc]")).to eq "<%i[abc]>"
  expect(wrap("%I[abc]")).to eq "<%I[abc]>"
  expect(wrap("%I[a\nb\nc]")).to eq "<%I[a\nb\nc]>"
end

it 'wraps complex and rational' do
  expect(wrap("1i")).to eq "<1i>"
  expect(wrap("5+1i")).to eq "<5+1i>"
  expect(wrap("1r")).to eq "<1r>"
  expect(wrap("1.5r")).to eq "<1.5r>"
  expect(wrap("1/2r")).to eq "<1/2r>"
  expect(wrap("2/1r")).to eq "<2/1r>"
  expect(wrap("1ri")).to eq "<1ri>"
end
