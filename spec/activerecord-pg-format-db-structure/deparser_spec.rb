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
      it "returns a formated query" do
        source = +<<~SQL
          SELECT * FROM my_table WHERE 1 = 1;
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)


          SELECT *
          FROM my_table
          WHERE 1 = 1;
        SQL
      end

      it "respects type casting" do
        source = +<<~SQL
          SELECT '1'::integer;
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)


          SELECT '1'::int;
        SQL
      end

      it "deals with complex queries" do
        source = +<<~SQL
          SELECT sum(foo) AS column_a,
                 case
                 when foo = 'a' then 1
                 when foo = 'b' then 2
                 else 3
                 end AS column_b
          FROM my_table
          WHERE bar > 10 OR bar < 5 OR (bar < 2 AND baz);
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)


          SELECT sum(foo) AS column_a,
                 CASE
                   WHEN foo = 'a' THEN 1
                   WHEN foo = 'b' THEN 2
                   ELSE 3
                 END AS column_b
          FROM my_table
          WHERE bar > 10
             OR bar < 5
             OR (bar < 2 AND baz);
        SQL
      end
    end

    context "with an insert statement" do
      it "returns a formated query" do
        source = +<<~SQL
          INSERT INTO schema_migrations (version) VALUES ('20250124155339'), ('20250134155339') , ('20250144155339');
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)



          INSERT INTO schema_migrations (version) VALUES
            ('20250124155339')
          , ('20250134155339')
          , ('20250144155339')
          ;
        SQL
      end

      it "also handles insert from select" do
        source = +<<~SQL
          INSERT INTO schema_migrations (version) SELECT foo from bar;

        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)



          INSERT INTO schema_migrations (version)
          SELECT foo
          FROM bar
          ;
        SQL
      end
    end

    context "with an index statement" do
      it "keeps it on a single line" do
        source = +<<~SQL
          CREATE UNIQUE INDEX only_one_pending_per_comment_id ON public.my_table USING btree (comment_id) WHERE pending;
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)

          CREATE UNIQUE INDEX only_one_pending_per_comment_id ON public.my_table USING btree (comment_id) WHERE pending;
        SQL
      end
    end

    context "with a create view statement" do
      it "returns a create statement where the body is formatted" do
        source = +<<~SQL
          CREATE VIEW public.post_stats AS (
            SELECT * FROM public.posts
          );
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)



          -- Name: post_stats; Type: VIEW;

          CREATE VIEW public.post_stats AS
              SELECT *
              FROM public.posts;
        SQL
      end

      it "works with non-select queries" do
        source = +<<~SQL
          CREATE VIEW public.post_stats AS (
            VALUES ('foo')
          );
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)



          -- Name: post_stats; Type: VIEW;

          CREATE VIEW public.post_stats AS
              VALUES ('foo');
        SQL
      end
    end

    context "with a CTE" do
      it "does a best effort at formatting" do
        source = +<<~SQL
          WITH my_cte AS (SELECT foo, baz FROM bar)
          SELECT * from my_cte;
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)


          WITH my_cte AS (
              SELECT foo,
                     baz
              FROM bar
          )
          SELECT *
          FROM my_cte;
        SQL
      end
    end

    context "with a create materialized view statement" do
      it "returns a create statement where the body is formatted" do
        source = +<<~SQL
          CREATE MATERIALIZED VIEW public.post_stats AS (
            SELECT * FROM public.posts
          );
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)



          -- Name: post_stats; Type: MATERIALIZED VIEW;

          CREATE MATERIALIZED VIEW public.post_stats AS
              SELECT *
              FROM public.posts;
        SQL
      end

      it "deals with WITH NO DATA suffix" do
        source = +<<~SQL
          CREATE MATERIALIZED VIEW public.post_stats AS (
            SELECT * FROM public.posts
          ) WITH NO DATA;
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)



          -- Name: post_stats; Type: MATERIALIZED VIEW;

          CREATE MATERIALIZED VIEW public.post_stats AS
              SELECT *
              FROM public.posts
          WITH NO DATA;
        SQL
      end
    end

    context "with some complex examples" do
      it "does its best" do
        source = +<<~SQL
          CREATE VIEW public.my_bigg_aggregated_view AS
              WITH first_cte AS (
                  SELECT main_1.id AS main_id,
                         main_1.comment_id
                  FROM public.my_main_table main_1
                  INNER JOIN public.user_comments ON user_comments.main_id = mains_1.id
                  LEFT OUTER JOIN public.main_users ON main_users.id = user_comments.main_user_id
                  WHERE main_users.type::text = 'first'::text
                  GROUP BY mains_1.id, mains_1.comment_id
                  ORDER BY mains_1.id
              ),
              second_cte AS (
                  SELECT mains_1.id AS main_id,
                         mains_1.comment_id
                  FROM public.mains mains_1
                  RIGHT JOIN public.main_user_mains ON main_user_mains.main_id = mains_1.id
                  JOIN public.main_users ON main_users.id = main_user_mains.main_user_id
                  WHERE main_users.type::text = 'second'::text
                  GROUP BY mains_1.id, mains_1.comment_id
              )
              SELECT mains.id AS main_id,
                     mains.comment_id,
                     main_status.visible AND NOT comments.public AND NOT mains.deleted AS published
              FROM public.mains
              JOIN public.comments ON comments.id = mains.comment_id
              LEFT JOIN first_cte ON mains.id = first_cte.main_id
              LEFT JOIN second_cte ON mains.id = second_cte.main_id
              CROSS JOIN LATERAL (
                SELECT mains.deleted_at IS NULL AND mains.title IS NOT NULL AND mains.title <> ''::public.citext AS listed
              ) main_status;
        SQL

        expect(formatter.format(source)).to eq(<<~SQL.chomp)



          -- Name: my_bigg_aggregated_view; Type: VIEW;

          CREATE VIEW public.my_bigg_aggregated_view AS
              WITH first_cte AS (
                  SELECT main_1.id AS main_id,
                         main_1.comment_id
                  FROM public.my_main_table main_1
                  JOIN public.user_comments ON user_comments.main_id = mains_1.id
                  LEFT JOIN public.main_users ON main_users.id = user_comments.main_user_id
                  WHERE main_users.type::text = 'first'::text
                  GROUP BY mains_1.id, mains_1.comment_id
                  ORDER BY mains_1.id
              ),
              second_cte AS (
                  SELECT mains_1.id AS main_id,
                         mains_1.comment_id
                  FROM public.mains mains_1
                  RIGHT JOIN public.main_user_mains ON main_user_mains.main_id = mains_1.id
                  JOIN public.main_users ON main_users.id = main_user_mains.main_user_id
                  WHERE main_users.type::text = 'second'::text
                  GROUP BY mains_1.id, mains_1.comment_id
              )
              SELECT mains.id AS main_id,
                     mains.comment_id,
                     main_status.visible AND NOT comments.public AND NOT mains.deleted AS published
              FROM public.mains
              JOIN public.comments ON comments.id = mains.comment_id
              LEFT JOIN first_cte ON mains.id = first_cte.main_id
              LEFT JOIN second_cte ON mains.id = second_cte.main_id
              CROSS JOIN LATERAL (
                  SELECT mains.deleted_at IS NULL AND mains.title IS NOT NULL AND mains.title <> ''::public.citext AS listed
              ) main_status;
        SQL
      end
    end
  end
end
