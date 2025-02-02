# frozen_string_literal: true

RSpec.describe ActiveRecordPgFormatDbStructure::Indenter do
  describe described_class::Output do
    describe "#current_token=" do
      it "ensures the previous token was appended before setting the next one", :aggregate_failures do
        output = described_class.new
        output.current_token = make_token(type: :SELECT, string: "SELECT")
        expect do
          output.current_token = make_token(type: :SELECT, string: "SELECT")
        end.to raise_error("Previous token was not appended!")

        output.append_token
        expect do
          output.current_token = make_token(type: :SELECT, string: "SELECT")
        end.not_to raise_error
      end
    end

    describe "#append_token" do
      it "ensures the current token is only appended once" do
        output = described_class.new
        output.current_token = make_token(type: :SELECT, string: "SELECT")
        output.append_token
        expect do
          output.append_token
        end.to raise_error("Token was already appended!")
      end
    end
  end

  def make_token(type:, string:)
    ActiveRecordPgFormatDbStructure::Indenter::Token.new(type:, string:)
  end
end
