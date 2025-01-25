# frozen_string_literal: true

RSpec.describe ActiveRecordPgFormatDbStructure::Preprocessors::RemoveWhitespaces do
  describe "#preprocess!" do
    it "trims whitespace and unnecessary comments from source" do
      source = +<<~SQL

        --
        -- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
        --

        CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


        --
        -- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
        --

        COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';

        --
        -- Name: comments; Type: TABLE; Schema: public; Owner: -
        --

      SQL

      described_class.new(source).preprocess!

      expect(source).to eq(<<~SQL)
        -- Name: pgcrypto; Type: EXTENSION

        CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


        -- Name: EXTENSION pgcrypto; Type: COMMENT

        COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';

        -- Name: comments; Type: TABLE
      SQL
    end
  end
end
