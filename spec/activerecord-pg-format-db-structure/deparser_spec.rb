# frozen_string_literal: true

RSpec.describe ActiveRecordPgFormatDbStructure::Deparser do
  let(:formatter) do
    ActiveRecordPgFormatDbStructure::Formatter.new(
      preprocessors: [],
      transforms: [],
      deparser: described_class
    )
  end

  describe "#deparse_raw_statement" do
    context "with a select query" do
      it "returns a formated query using anbt-sql-formatter" do
        source = +<<~SQL
          SELECT * FROM my_table WHERE 1 = 1;
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)


          SELECT
                  *
              FROM
                  my_table
              WHERE
                  1 = 1;
        SQL
      end
    end

    context "with an insert statement" do
      it "returns a formated query using anbt-sql-formatter" do
        source = +<<~SQL
          INSERT INTO schema_migrations (version) VALUES ('20250124155339'), ('20250134155339') , ('20250144155339');
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)



          INSERT INTO schema_migrations (version) VALUES
           ('20250124155339')
          ,('20250134155339')
          ,('20250144155339')
          ;
        SQL
      end
    end

    context "with a create view statement" do
      it "returns a create statement where the body is formatted using anbt-sql-formatter" do
        source = +<<~SQL
          CREATE VIEW public.post_stats AS (
            SELECT * FROM public.posts
          );
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)


          CREATE VIEW public.post_stats AS (
              SELECT
                      *
                  FROM
                      public.posts
          );
        SQL
      end
    end

    context "with a create materialized view statement" do
      it "returns a create statement where the body is formatted using anbt-sql-formatter" do
        source = +<<~SQL
          CREATE MATERIALIZED VIEW public.post_stats AS (
            SELECT * FROM public.posts
          );
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)


          CREATE MATERIALIZED VIEW public.post_stats AS (
              SELECT
                      *
                  FROM
                      public.posts
          );
        SQL
      end
    end
  end
end
