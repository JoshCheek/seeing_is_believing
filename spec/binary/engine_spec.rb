require 'seeing_is_believing/binary/engine'
require 'seeing_is_believing/binary/parse_args'
require 'seeing_is_believing/binary/options'

class SeeingIsBelieving
  module Binary
    RSpec.describe Engine do
      let(:stdin)  { double :stdin }
      let(:stdout) { double :stdout }

      def call(body)
        flags   = ParseArgs.call []
        flags[:program_from_args] = body
        options = Options.new(flags, stdin, stdout)
        Engine.new options
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
        it 'ends in a newline if the body ended in a newline' do
          expect(call("1").cleaned_body).to eq "1"
          expect(call("1\n").cleaned_body).to eq "1\n"
        end
        it 'has the annotations removed' do
          expect(call("1 # =>").cleaned_body).to eq "1"
        end
      end

      # context 'annotated_body' do
      #   before { pending "unimplemented"; raise }
      #   it 'ends in a newline if the body ended in a newline' do
      #     expect(call(program_from_args: "1").annotated_body).to eq "1  # => 1"
      #     expect(call(program_from_args: "1\n").annotated_body).to eq "1  # => 1\n"
      #   end
      #   it 'is the body after being run through the annotator' do
      #     expect(call(program_from_args: "1").annotated_body).to eq "1  # => 1"
      #   end
      # end

      context 'prepared_body' do
        it 'ends in a newline, regardless of whether the body did' do
          expect(call("1").prepared_body).to eq "1\n"
          expect(call("1\n").prepared_body).to eq "1\n"
        end
        it 'is the body after being run throught he annotator\'s prepare method' do
          expect(call('1+1 # => ').prepared_body).to eq "1+1\n"
        end
      end
    end
  end
end
