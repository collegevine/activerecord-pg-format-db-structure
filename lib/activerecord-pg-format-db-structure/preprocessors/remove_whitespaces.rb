# frozen_string_literal: true

module ActiveRecordPgFormatDbStructure
  module Preprocessors
    # Remove whitespace and SQL comments from an SQL string
    class RemoveWhitespaces
      attr_reader :source

      def initialize(source)
        @source = source
      end

      def preprocess!
        # Remove trailing whitespace
        source.gsub!(/[ \t]+$/, "")
        source.gsub!(/\A\n/, "")
        source.gsub!(/\n\n\z/, "\n")

        # Remove useless comment lines
        source.gsub!(/^--\n/, "")

        # Remove useless, version-specific parts of comments
        source.gsub!(/^-- (.*); Schema: ([\w.]+|-); Owner: -.*/, '-- \1')
      end
    end
  end
end
