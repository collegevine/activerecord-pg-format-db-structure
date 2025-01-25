# frozen_string_literal: true

RSpec.describe ActiveRecordPgFormatDbStructure::Transforms::MoveIndicesAfterCreateTable do
  describe "#transform!" do
    it "inline non-foreign key constraints in the table declaration" do
      formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
        transforms: [described_class]
      )

      source = +<<~SQL
        CREATE TABLE public.comments (
            id bigint NOT NULL,
            user_id bigint NOT NULL,
            post_id bigint NOT NULL
        );

        CREATE TABLE public.posts (
            id bigint NOT NULL,
            score int NOT NULL
        );

        CREATE MATERIALIZED VIEW public.post_stats AS (
          SELECT * FROM public.posts
        );

        CREATE TABLE public.users (
            id bigint NOT NULL,
            email text not null
        );

        CREATE INDEX index_users_on_id ON public.users USING btree (id);
        CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);
        CREATE INDEX index_comments_on_id ON public.comments USING btree (id);
        CREATE INDEX index_comments_on_user_id ON public.comments USING btree (user_id);
        CREATE INDEX index_comments_on_post_id ON public.comments USING btree (post_id);
        CREATE INDEX index_post_stats_on_score ON public.post_stats USING btree (score);

        INSERT INTO "schema_migrations" (version) VALUES
        ('20250124155339');
      SQL

      expect(formatter.format(source)).to eq(<<~SQL.chomp)



        -- Name: comments; Type: TABLE;

        CREATE TABLE public.comments (
            id bigint NOT NULL,
            user_id bigint NOT NULL,
            post_id bigint NOT NULL
        );
        CREATE INDEX index_comments_on_id ON public.comments USING btree (id);
        CREATE INDEX index_comments_on_post_id ON public.comments USING btree (post_id);
        CREATE INDEX index_comments_on_user_id ON public.comments USING btree (user_id);


        -- Name: posts; Type: TABLE;

        CREATE TABLE public.posts (
            id bigint NOT NULL,
            score int NOT NULL
        );

        CREATE MATERIALIZED VIEW public.post_stats AS (
          SELECT * FROM public.posts
        );
        CREATE INDEX index_post_stats_on_score ON public.post_stats USING btree (score);


        -- Name: users; Type: TABLE;

        CREATE TABLE public.users (
            id bigint NOT NULL,
            email text NOT NULL
        );
        CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);
        CREATE INDEX index_users_on_id ON public.users USING btree (id);

        INSERT INTO "schema_migrations" (version) VALUES
        ('20250124155339');
      SQL
    end
  end
end
