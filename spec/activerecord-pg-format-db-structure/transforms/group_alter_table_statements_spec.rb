# frozen_string_literal: true

RSpec.describe ActiveRecordPgFormatDbStructure::Transforms::GroupAlterTableStatements do
  describe "#transform!" do
    it "groups alter statements after all table and index declarations" do
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

        CREATE TABLE public.posts (
            id bigint NOT NULL,
            created_at timestamp(6) without time zone NOT NULL,
            updated_at timestamp(6) without time zone NOT NULL
        );

        CREATE TABLE public.users (
            id bigint NOT NULL,
            created_at timestamp(6) without time zone NOT NULL,
            updated_at timestamp(6) without time zone NOT NULL
        );

        CREATE INDEX my_index ON public.users USING btree (id);

        ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);

        ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);

        ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);

        ALTER TABLE ONLY public.comments
            ADD CONSTRAINT comments_pkey PRIMARY KEY (id);

        ALTER TABLE ONLY public.posts
            ADD CONSTRAINT posts_pkey PRIMARY KEY (id);

        ALTER TABLE ONLY public.users
            ADD CONSTRAINT users_pkey PRIMARY KEY (id);

        ALTER TABLE ONLY public.comments
            ADD CONSTRAINT fk_rails_0000000001 FOREIGN KEY (post_id) REFERENCES public.posts(id);

        ALTER TABLE ONLY public.comments
            ADD CONSTRAINT fk_rails_0000000002 FOREIGN KEY (user_id) REFERENCES public.users(id);


        INSERT INTO "schema_migrations" (version) VALUES
        ('20250124155339');
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


        -- Name: posts; Type: TABLE;

        CREATE TABLE public.posts (
            id bigint NOT NULL,
            created_at timestamp(6) NOT NULL,
            updated_at timestamp(6) NOT NULL
        );


        -- Name: users; Type: TABLE;

        CREATE TABLE public.users (
            id bigint NOT NULL,
            created_at timestamp(6) NOT NULL,
            updated_at timestamp(6) NOT NULL
        );
        CREATE INDEX my_index ON public.users USING btree (id);

        ALTER TABLE ONLY public.comments
          ADD CONSTRAINT fk_rails_0000000001 FOREIGN KEY (post_id) REFERENCES public.posts (id),
          ADD CONSTRAINT fk_rails_0000000002 FOREIGN KEY (user_id) REFERENCES public.users (id),
          ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass),
          ADD CONSTRAINT comments_pkey PRIMARY KEY (id);

        ALTER TABLE ONLY public.posts
          ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass),
          ADD CONSTRAINT posts_pkey PRIMARY KEY (id);

        ALTER TABLE ONLY public.users
          ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass),
          ADD CONSTRAINT users_pkey PRIMARY KEY (id);


        INSERT INTO "schema_migrations" (version) VALUES
        ('20250124155339');
      SQL
    end

    it "does nothing if there are no alter statements" do
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

        CREATE TABLE public.posts (
            id bigint NOT NULL,
            created_at timestamp(6) without time zone NOT NULL,
            updated_at timestamp(6) without time zone NOT NULL
        );

        CREATE TABLE public.users (
            id bigint NOT NULL,
            created_at timestamp(6) without time zone NOT NULL,
            updated_at timestamp(6) without time zone NOT NULL
        );

        CREATE INDEX my_index ON public.users USING btree (id);

        INSERT INTO "schema_migrations" (version) VALUES
        ('20250124155339');
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


        -- Name: posts; Type: TABLE;

        CREATE TABLE public.posts (
            id bigint NOT NULL,
            created_at timestamp(6) NOT NULL,
            updated_at timestamp(6) NOT NULL
        );


        -- Name: users; Type: TABLE;

        CREATE TABLE public.users (
            id bigint NOT NULL,
            created_at timestamp(6) NOT NULL,
            updated_at timestamp(6) NOT NULL
        );
        CREATE INDEX my_index ON public.users USING btree (id);

        INSERT INTO "schema_migrations" (version) VALUES
        ('20250124155339');
      SQL
    end
  end
end
