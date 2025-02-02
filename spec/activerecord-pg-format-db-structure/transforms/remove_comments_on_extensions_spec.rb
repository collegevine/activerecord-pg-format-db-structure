# frozen_string_literal: true

RSpec.describe ActiveRecordPgFormatDbStructure::Transforms::RemoveCommentsOnExtensions do
  describe "#transform!" do
    it "remove COMMENT on extensions" do
      formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
        transforms: [described_class]
      )

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

        CREATE TABLE public.comments (
            id bigint NOT NULL,
            user_id bigint NOT NULL,
            post_id bigint NOT NULL,
            created_at timestamp(6) without time zone NOT NULL,
            updated_at timestamp(6) without time zone NOT NULL
        );

        INSERT INTO "schema_migrations" (version) VALUES
        ('20250124155339');
      SQL

      expect(formatter.format(source)).to eq(<<~SQL.chomp)


        CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA public;


        -- Name: comments; Type: TABLE;

        CREATE TABLE public.comments (
            id bigint NOT NULL,
            user_id bigint NOT NULL,
            post_id bigint NOT NULL,
            created_at timestamp(6) NOT NULL,
            updated_at timestamp(6) NOT NULL
        );


        INSERT INTO schema_migrations (version) VALUES
          ('20250124155339')
        ;
      SQL
    end
  end
end
