# doesn't get run directly, rather gets eval'd in wrap_expressions_spec
# if we are on Ruby 2+

it 'respects __dir__ macro' do
  expect(wrap('__dir__')).to eq '<__dir__>'
end
