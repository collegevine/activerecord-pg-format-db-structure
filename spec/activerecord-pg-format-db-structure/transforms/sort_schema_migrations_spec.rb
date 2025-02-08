# frozen_string_literal: true

RSpec.describe ActiveRecordPgFormatDbStructure::Transforms::SortSchemaMigrations do
  describe "#transform!" do
    it "sorts schema_migrations insert in chronological order" do
      formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
        transforms: [described_class]
      )

      source = +<<~SQL
        CREATE TABLE public.comments (
            id bigint NOT NULL,
            user_id bigint NOT NULL,
            post_id bigint NOT NULL,
            created_at timestamp(6) without time zone NOT NULL,
            updated_at timestamp(6) without time zone NOT NULL
        );

        INSERT INTO "schema_migrations" (version) VALUES
        ('20250101000004'),
        ('20250101000002'),
        ('20250101000003'),
        ('20250101000001');
      SQL

      expect(formatter.format(source)).to eq(<<~SQL.chomp)



        -- Name: comments; Type: TABLE;

        CREATE TABLE public.comments (
            id bigint NOT NULL,
            user_id bigint NOT NULL,
            post_id bigint NOT NULL,
            created_at timestamp(6) NOT NULL,
            updated_at timestamp(6) NOT NULL
        );


        INSERT INTO schema_migrations (version) VALUES
          ('20250101000001')
        , ('20250101000002')
        , ('20250101000003')
        , ('20250101000004')
        ;
      SQL
    end
  end
end
