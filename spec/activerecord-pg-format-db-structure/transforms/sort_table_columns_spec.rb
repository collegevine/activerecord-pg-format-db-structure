# frozen_string_literal: true

RSpec.describe ActiveRecordPgFormatDbStructure::Transforms::SortTableColumns do
  describe "#transform!" do
    it "sorts columns in order of primary key / foreign keys / data / timestamps / constraints" do
      formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
        transforms: [described_class]
      )

      source = +<<~SQL
        CREATE TABLE public.comments (
            id bigint PRIMARY KEY,
            user_id bigint NOT NULL,
            post_id bigint NOT NULL CONSTRAINT fk_rails_0000000001 REFERENCES public.posts(id),
            parent_id bigint NOT NULL,
            score int NOT NULL,
            created_at timestamp(6) without time zone NOT NULL,
            updated_at timestamp(6) without time zone NOT NULL,
            CONSTRAINT postive_score CHECK (score > 0),
            CHECK (score < 10),
            CONSTRAINT fk_rails_0000000002 FOREIGN KEY (parent_id) REFERENCES public.comments(id)
        );

        ALTER TABLE ONLY public.comments
          ADD CONSTRAINT fk_rails_0000000003 FOREIGN KEY (user_id) REFERENCES public.users(id),
          ADD CONSTRAINT postive_score_take_2 CHECK (score > 0);
      SQL

      expect(formatter.format(source)).to eq(<<~SQL.chomp)



        -- Name: comments; Type: TABLE;

        CREATE TABLE public.comments (
            id bigint PRIMARY KEY,
            parent_id bigint NOT NULL,
            post_id bigint NOT NULL CONSTRAINT fk_rails_0000000001 REFERENCES public.posts (id),
            user_id bigint NOT NULL,
            score int NOT NULL,
            created_at timestamp(6) NOT NULL,
            updated_at timestamp(6) NOT NULL,
            CHECK (score < 10),
            CONSTRAINT fk_rails_0000000002 FOREIGN KEY (parent_id) REFERENCES public.comments (id),
            CONSTRAINT postive_score CHECK (score > 0)
        );

        ALTER TABLE ONLY public.comments
          ADD CONSTRAINT fk_rails_0000000003 FOREIGN KEY (user_id) REFERENCES public.users (id),
          ADD CONSTRAINT postive_score_take_2 CHECK (score > 0);
      SQL
    end

    it "works if primary key is defined in an alter table" do
      formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
        transforms: [described_class]
      )

      source = +<<~SQL
        CREATE TABLE public.comments (
            id bigint NOT NULL,
            user_id bigint NOT NULL,
            post_id bigint NOT NULL,
            parent_id bigint NOT NULL,
            score int NOT NULL,
            created_at timestamp(6) without time zone NOT NULL,
            updated_at timestamp(6) without time zone NOT NULL,
            CONSTRAINT postive_score CHECK (score > 0),
            CHECK (score < 10)
        );

        ALTER TABLE ONLY public.comments
          ADD CONSTRAINT posts_pkey PRIMARY KEY (id),
          ADD CONSTRAINT fk_rails_0000000001 FOREIGN KEY (post_id) REFERENCES public.posts(id),
          ADD CONSTRAINT fk_rails_0000000002 FOREIGN KEY (parent_id) REFERENCES public.comments(id),
          ADD CONSTRAINT fk_rails_0000000003 FOREIGN KEY (user_id) REFERENCES public.users(id);

      SQL

      expect(formatter.format(source)).to eq(<<~SQL.chomp)



        -- Name: comments; Type: TABLE;

        CREATE TABLE public.comments (
            id bigint NOT NULL,
            parent_id bigint NOT NULL,
            post_id bigint NOT NULL,
            user_id bigint NOT NULL,
            score int NOT NULL,
            created_at timestamp(6) NOT NULL,
            updated_at timestamp(6) NOT NULL,
            CHECK (score < 10),
            CONSTRAINT postive_score CHECK (score > 0)
        );

        ALTER TABLE ONLY public.comments
          ADD CONSTRAINT posts_pkey PRIMARY KEY (id),
          ADD CONSTRAINT fk_rails_0000000001 FOREIGN KEY (post_id) REFERENCES public.posts (id),
          ADD CONSTRAINT fk_rails_0000000002 FOREIGN KEY (parent_id) REFERENCES public.comments (id),
          ADD CONSTRAINT fk_rails_0000000003 FOREIGN KEY (user_id) REFERENCES public.users (id);
      SQL
    end

    it "works if primary key is defined as a table constraint" do
      formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
        transforms: [described_class]
      )

      source = +<<~SQL
        CREATE TABLE public.comments (
            id bigint NOT NULL,
            user_id bigint NOT NULL,
            post_id bigint NOT NULL,
            parent_id bigint NOT NULL,
            score int NOT NULL,
            created_at timestamp(6) without time zone NOT NULL,
            updated_at timestamp(6) without time zone NOT NULL,
            CONSTRAINT postive_score CHECK (score > 0),
            CHECK (score < 10),
            CONSTRAINT posts_pkey PRIMARY KEY (id)
        );

        ALTER TABLE ONLY public.comments
          ADD CONSTRAINT fk_rails_0000000001 FOREIGN KEY (post_id) REFERENCES public.posts(id),
          ADD CONSTRAINT fk_rails_0000000002 FOREIGN KEY (parent_id) REFERENCES public.comments(id),
          ADD CONSTRAINT fk_rails_0000000003 FOREIGN KEY (user_id) REFERENCES public.users(id);

      SQL

      expect(formatter.format(source)).to eq(<<~SQL.chomp)



        -- Name: comments; Type: TABLE;

        CREATE TABLE public.comments (
            id bigint NOT NULL,
            parent_id bigint NOT NULL,
            post_id bigint NOT NULL,
            user_id bigint NOT NULL,
            score int NOT NULL,
            created_at timestamp(6) NOT NULL,
            updated_at timestamp(6) NOT NULL,
            CHECK (score < 10),
            CONSTRAINT postive_score CHECK (score > 0),
            CONSTRAINT posts_pkey PRIMARY KEY (id)
        );

        ALTER TABLE ONLY public.comments
          ADD CONSTRAINT fk_rails_0000000001 FOREIGN KEY (post_id) REFERENCES public.posts (id),
          ADD CONSTRAINT fk_rails_0000000002 FOREIGN KEY (parent_id) REFERENCES public.comments (id),
          ADD CONSTRAINT fk_rails_0000000003 FOREIGN KEY (user_id) REFERENCES public.users (id);
      SQL
    end
  end
end
