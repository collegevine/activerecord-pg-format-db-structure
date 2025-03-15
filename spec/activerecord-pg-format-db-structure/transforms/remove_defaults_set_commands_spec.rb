# frozen_string_literal: true

RSpec.describe ActiveRecordPgFormatDbStructure::Transforms::RemoveDefaultsSetCommands do
  describe "#transform!" do
    it "removes SET command with default values" do
      formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
        transforms: [described_class]
      )

      source = +<<~SQL
        SET statement_timeout = 0;
        SET default_with_oids = false;
        SET lock_timeout = 0;
        SET idle_in_transaction_session_timeout = 0;
        SET client_encoding = 'UTF8';
        SET standard_conforming_strings = on;
        SELECT pg_catalog.set_config('search_path', '', false);
        SET check_function_bodies = false;
        SET xmloption = content;
        SET client_min_messages = warning;
        SET row_security = off;
      SQL

      expect(formatter.format(source)).to eq(<<~SQL)
        SET client_encoding TO "UTF8";

        SELECT pg_catalog.set_config('search_path', '', false);

        SET check_function_bodies TO FALSE;
        SET client_min_messages TO warning;
        SET row_security TO OFF;
      SQL
    end

    it "preserves SET command with non-default values" do
      formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
        transforms: [described_class]
      )

      source = +<<~SQL
        SET statement_timeout = 1;
        SET default_with_oids = true;
        SET lock_timeout = 2;
        SET idle_in_transaction_session_timeout = 3;
        SET client_encoding = 'UTF8';
        SET standard_conforming_strings = off;
        SELECT pg_catalog.set_config('search_path', '', false);
        SET check_function_bodies = false;
        SET xmloption = content;
        SET client_min_messages = warning;
        SET row_security = on;
      SQL

      expect(formatter.format(source)).to eq(<<~SQL)
        SET statement_timeout TO 1;
        SET default_with_oids TO TRUE;
        SET lock_timeout TO 2;
        SET idle_in_transaction_session_timeout TO 3;
        SET client_encoding TO "UTF8";
        SET standard_conforming_strings TO OFF;

        SELECT pg_catalog.set_config('search_path', '', false);

        SET check_function_bodies TO FALSE;
        SET client_min_messages TO warning;
        SET row_security TO ON;
      SQL
    end

    it "deals with values that are neither strigns nor ints" do
      formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
        transforms: [described_class]
      )

      source = +<<~SQL
        SET statement_timeout = 10.0;
      SQL

      expect(formatter.format(source)).to eq(<<~SQL)
        SET statement_timeout TO 10.0;
      SQL
    end
  end
end
