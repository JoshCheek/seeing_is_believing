require 'seeing_is_believing/binary/engine'
require 'seeing_is_believing/binary/config'

class SeeingIsBelieving
  module Binary
    RSpec.describe Engine do
      class Options < HashStruct
        attribute :timeout, 0
      end

      def call(body, options={})
        timeout = Options.new(options).timeout
        config  = Config.new body: body, timeout_seconds: timeout
        config.lib_options.timeout_seconds = timeout
        Engine.new config
      end

      def assert_must_evaluate(message)
        engine = call ''
        expect { engine.__send__ message }.to raise_error MustEvaluateFirst, /#{message}/
        engine.evaluate!
        engine.__send__ message
      end

      context 'syntax' do
        let(:valid_engine)   { call "1+1" }
        let(:invalid_engine) { call "1+"  }

        specify 'syntax_error? is true when the body was syntactically invalid' do
          expect(  valid_engine.syntax_error?).to eq false
          expect(invalid_engine.syntax_error?).to eq true
        end

        specify 'syntax_error_message contains the syntax\'s error message with line information embedded into it' do
          expect(valid_engine.syntax_error_message).to eq ""

          allow_any_instance_of(Code::Syntax).to receive(:error_message).and_return "ERR!!"
          allow_any_instance_of(Code::Syntax).to receive(:line_number).and_return   123
          expect(invalid_engine.syntax_error_message).to eq "123: ERR!!"
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

      context 'prepared_body' do
        it 'is the body after being run throught he annotator\'s prepare method' do
          expect(call('1+1 # => ').prepared_body).to eq "1+1\n"
        end
        it 'ends in a newline, regardless of whether the body did' do
          expect(call("1").prepared_body).to eq "1\n"
          expect(call("1\n").prepared_body).to eq "1\n"
        end
      end

      context 'before evaluating it raises if asked for' do
        specify('results')               { assert_must_evaluate :results }
        specify('timed_out?')            { assert_must_evaluate :timed_out? }
        specify('annotated_body')        { assert_must_evaluate :annotated_body }
        specify('unexpected_exception')  { assert_must_evaluate :unexpected_exception }
        specify('unexpected_exception?') { assert_must_evaluate :unexpected_exception? }
      end

      context 'after evaluating' do
        specify 'results are the results of the evaluation' do
          status = call('exit 55').evaluate!.results.exitstatus
          expect(status).to eq 55
        end

        specify 'timed_out? is true if the program raised a Timeout::Error' do
          expect(call('', timeout: 1).evaluate!.timed_out?).to eq false
          expect(call('sleep 1', timeout: 0.01).evaluate!.timed_out?).to eq true
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
