require 'seeing_is_believing/binary/engine'
require 'seeing_is_believing/binary/config'

class SeeingIsBelieving
  module Binary
    RSpec.describe Engine do
      def call(body, options={})
        timeout  = options.fetch :timeout, 0
        filename = options.fetch :filename, "program.rb"
        toggle   = options.fetch :toggled_mark, nil
        config   = Config.new body: body, timeout_seconds: timeout, toggle_mark: toggle
        config.lib_options.timeout_seconds = timeout
        config.lib_options.filename        = filename
        Engine.new config
      end

      def assert_must_evaluate(message)
        engine = call '1+1'
        expect { engine.__send__ message }.to raise_error MustEvaluateFirst, /#{message}/
        engine.evaluate!
        engine.__send__ message
      end

      context 'syntax' do
        let(:valid_engine)   { call "1+1", filename: "filename.rb" }
        let(:invalid_engine) { call "1+",  filename: "filename.rb" }

        specify 'syntax_error? is true when the body was syntactically invalid' do
          expect(  valid_engine.syntax_error?).to eq false
          expect(invalid_engine.syntax_error?).to eq true
        end

        specify 'syntax_error contains the syntax\'s error message with file and line information' do
          expect(valid_engine.syntax_error).to eq nil

          allow_any_instance_of(Code::Syntax).to receive(:error_message).and_return "ERR!!"
          allow_any_instance_of(Code::Syntax).to receive(:line_number).and_return   123
          expect(invalid_engine.syntax_error)
            .to eq SyntaxErrorMessage.new(line_number: 123, filename: "filename.rb", explanation: "ERR!!")
          expect(invalid_engine.syntax_error.to_s).to include "ERR!!"
        end
      end

      context 'cleaned_body' do
        it 'has the annotations removed' do
          expect(call("1 # =>").cleaned_body).to eq "1"
        end
        it 'ends in a newline if the body ended in a newline' do
          expect(call("1").cleaned_body).to eq "1"
          expect(call("1\n").cleaned_body).to eq "1\n"
        end
      end

      context 'toggled_mark' do
        it 'has the mark toggled and doesn\'t change the newline' do
          expect(call("1",        toggled_mark: 1).toggled_mark).to eq "1  # => "
          expect(call("1 # => ",  toggled_mark: 1).toggled_mark).to eq "1"
          expect(call("1\n",      toggled_mark: 1).toggled_mark).to eq "1  # => \n"
          expect(call("1 # =>\n", toggled_mark: 1).toggled_mark).to eq "1\n"
        end
      end

      context 'before evaluating it raises if asked for' do
        specify('result')          { assert_must_evaluate :result }
        specify('exitstatus')      { assert_must_evaluate :exitstatus }
        specify('timed_out?')      { assert_must_evaluate :timed_out? }
        specify('timeout_seconds') { assert_must_evaluate :timeout_seconds }
        specify('annotated_body')  { assert_must_evaluate :annotated_body }
      end

      context 'after evaluating' do
        specify 'result is the result of the evaluation' do
          status = call('exit 55').evaluate!.result.exitstatus
          expect(status).to eq 55
        end

        it 'has recorded the exitstatus' do
          engine = call('exit 88')
          engine.evaluate!
          expect(engine.exitstatus).to eq 88
        end

        specify 'timed_out? is true if a Timeout event was emitted' do
          expect(call('', timeout: 1).evaluate!.timed_out?).to eq false
          expect(call('sleep 1', timeout: 0.01).evaluate!.timed_out?).to eq true
        end

        specify 'timeout_seconds is nil, or the timeout duration' do
          expect(call('', timeout: 1).evaluate!.timeout_seconds).to eq nil
          expect(call('sleep 1', timeout: 0.01).evaluate!.timeout_seconds).to eq 0.01
        end

        context 'annotated_body' do
          it 'is the body after being run through the annotator' do
            expect(call("1").evaluate!.annotated_body).to eq "1  # => 1"
          end
          it 'ends in a newline if the body ended in a newline' do
            expect(call("1").evaluate!.annotated_body).to eq "1  # => 1"
            expect(call("1\n").evaluate!.annotated_body).to eq "1  # => 1\n"
          end
        end

        it 'evaluation errors are raised up, and it behaves as if it was not evaluated' do
          evaluated   = call('1').evaluate!
          unevaluated = call '1'
          expect(SeeingIsBelieving).to receive(:call).exactly(2).times.and_raise(ArgumentError)
          evaluated.evaluate!
          expect { unevaluated.evaluate! }.to raise_error ArgumentError
          expect { unevaluated.evaluate! }.to raise_error ArgumentError
        end
      end
    end
  end
end
