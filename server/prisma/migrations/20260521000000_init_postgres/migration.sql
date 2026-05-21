-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "email" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'user',
    "avatar" TEXT,
    "phone" TEXT,
    "bio" VARCHAR(300),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "is_verified" BOOLEAN NOT NULL DEFAULT false,
    "fcm_token" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "icon" TEXT NOT NULL DEFAULT 'news',
    "color" TEXT NOT NULL DEFAULT '#1D9E75',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "news_posts" (
    "id" UUID NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "body" TEXT NOT NULL,
    "summary" VARCHAR(300),
    "reporter_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "rejection_reason" TEXT,
    "approved_by_id" UUID,
    "approved_at" TIMESTAMP(3),
    "views" INTEGER NOT NULL DEFAULT 0,
    "likes" INTEGER NOT NULL DEFAULT 0,
    "is_featured" BOOLEAN NOT NULL DEFAULT false,
    "is_breaking" BOOLEAN NOT NULL DEFAULT false,
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "language" TEXT NOT NULL DEFAULT 'en',
    "original_language" VARCHAR(12),
    "source_name" TEXT,
    "source_url" TEXT,
    "source_url_hash" TEXT,
    "title_normalized" TEXT,
    "title_fingerprint" TEXT,
    "summary_fingerprint" TEXT,
    "source_published_at" TIMESTAMP(3),
    "source_type" TEXT NOT NULL DEFAULT 'manual',
    "youtube_video_id" TEXT,
    "youtube_channel_id" TEXT,
    "youtube_channel_title" TEXT,
    "youtube_embed_url" TEXT,
    "youtube_watch_url" TEXT,
    "youtube_channel_url" TEXT,
    "youtube_duration_seconds" INTEGER,
    "youtube_is_short" BOOLEAN,
    "youtube_embeddable" BOOLEAN,
    "youtube_privacy_status" TEXT,
    "location_latitude" DOUBLE PRECISION,
    "location_longitude" DOUBLE PRECISION,
    "location_address" TEXT,
    "location_city" TEXT,
    "location_state" TEXT,
    "location_country" TEXT DEFAULT 'India',
    "location_captured_at" TIMESTAMP(3),
    "politics_scope" TEXT,
    "constituency" TEXT DEFAULT 'Unknown',
    "scraped_at" TIMESTAMP(3),
    "scrape_confidence" DOUBLE PRECISION,
    "video_category" TEXT,
    "video_classification_method" TEXT,
    "video_classification_score" DOUBLE PRECISION,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "news_posts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "news_post_media" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "type" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "thumbnail" TEXT,
    "public_id" TEXT,
    "size" INTEGER NOT NULL DEFAULT 0,
    "duration" INTEGER,
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "news_post_media_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "news_post_entities" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "text" TEXT,
    "label" TEXT,

    CONSTRAINT "news_post_entities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "comments" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "text" VARCHAR(1000) NOT NULL,
    "likes" INTEGER NOT NULL DEFAULT 0,
    "is_deleted" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "otps" (
    "id" UUID NOT NULL,
    "target" TEXT NOT NULL,
    "channel" TEXT NOT NULL,
    "purpose" TEXT NOT NULL,
    "code_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "otps_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "political_videos" (
    "id" UUID NOT NULL,
    "video_id" TEXT NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "thumbnail" TEXT,
    "channel_name" TEXT,
    "channel_id" TEXT,
    "language" TEXT NOT NULL DEFAULT 'en',
    "published_at" TIMESTAMP(3),
    "category" TEXT,
    "classification_method" TEXT NOT NULL DEFAULT 'keyword',
    "classification_score" DOUBLE PRECISION,
    "description" VARCHAR(500),
    "news_post_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "political_videos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "post_likes" (
    "user_id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_likes_pkey" PRIMARY KEY ("user_id","post_id")
);

-- CreateTable
CREATE TABLE "user_bookmarks" (
    "user_id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_bookmarks_pkey" PRIMARY KEY ("user_id","post_id")
);

-- CreateTable
CREATE TABLE "user_preferred_categories" (
    "user_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_preferred_categories_pkey" PRIMARY KEY ("user_id","category_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE INDEX "users_role_idx" ON "users"("role");

-- CreateIndex
CREATE UNIQUE INDEX "categories_name_key" ON "categories"("name");

-- CreateIndex
CREATE UNIQUE INDEX "categories_slug_key" ON "categories"("slug");

-- CreateIndex
CREATE INDEX "categories_is_active_order_name_idx" ON "categories"("is_active", "order", "name");

-- CreateIndex
CREATE UNIQUE INDEX "news_posts_source_url_hash_key" ON "news_posts"("source_url_hash");

-- CreateIndex
CREATE UNIQUE INDEX "news_posts_title_fingerprint_key" ON "news_posts"("title_fingerprint");

-- CreateIndex
CREATE UNIQUE INDEX "news_posts_youtube_video_id_key" ON "news_posts"("youtube_video_id");

-- CreateIndex
CREATE INDEX "news_posts_status_created_at_idx" ON "news_posts"("status", "created_at");

-- CreateIndex
CREATE INDEX "news_posts_category_id_status_created_at_idx" ON "news_posts"("category_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "news_posts_category_id_status_source_published_at_idx" ON "news_posts"("category_id", "status", "source_published_at");

-- CreateIndex
CREATE INDEX "news_posts_title_normalized_status_created_at_idx" ON "news_posts"("title_normalized", "status", "created_at");

-- CreateIndex
CREATE INDEX "news_posts_reporter_id_created_at_idx" ON "news_posts"("reporter_id", "created_at");

-- CreateIndex
CREATE INDEX "news_posts_location_city_status_idx" ON "news_posts"("location_city", "status");

-- CreateIndex
CREATE INDEX "news_posts_language_status_created_at_idx" ON "news_posts"("language", "status", "created_at");

-- CreateIndex
CREATE INDEX "news_posts_status_source_type_source_published_at_idx" ON "news_posts"("status", "source_type", "source_published_at");

-- CreateIndex
CREATE INDEX "news_posts_politics_scope_idx" ON "news_posts"("politics_scope");

-- CreateIndex
CREATE INDEX "news_posts_constituency_idx" ON "news_posts"("constituency");

-- CreateIndex
CREATE INDEX "news_posts_video_category_idx" ON "news_posts"("video_category");

-- CreateIndex
CREATE INDEX "news_post_media_post_id_order_idx" ON "news_post_media"("post_id", "order");

-- CreateIndex
CREATE INDEX "news_post_entities_post_id_idx" ON "news_post_entities"("post_id");

-- CreateIndex
CREATE INDEX "comments_post_id_created_at_idx" ON "comments"("post_id", "created_at");

-- CreateIndex
CREATE INDEX "otps_target_purpose_idx" ON "otps"("target", "purpose");

-- CreateIndex
CREATE INDEX "otps_expires_at_idx" ON "otps"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "political_videos_video_id_key" ON "political_videos"("video_id");

-- CreateIndex
CREATE UNIQUE INDEX "political_videos_news_post_id_key" ON "political_videos"("news_post_id");

-- CreateIndex
CREATE INDEX "political_videos_language_published_at_idx" ON "political_videos"("language", "published_at");

-- CreateIndex
CREATE INDEX "political_videos_category_published_at_idx" ON "political_videos"("category", "published_at");

-- CreateIndex
CREATE INDEX "post_likes_post_id_idx" ON "post_likes"("post_id");

-- CreateIndex
CREATE INDEX "user_bookmarks_post_id_idx" ON "user_bookmarks"("post_id");

-- CreateIndex
CREATE INDEX "user_bookmarks_user_id_created_at_idx" ON "user_bookmarks"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "user_preferred_categories_category_id_idx" ON "user_preferred_categories"("category_id");

-- AddForeignKey
ALTER TABLE "news_posts" ADD CONSTRAINT "news_posts_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "news_posts" ADD CONSTRAINT "news_posts_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "news_posts" ADD CONSTRAINT "news_posts_approved_by_id_fkey" FOREIGN KEY ("approved_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "news_post_media" ADD CONSTRAINT "news_post_media_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "news_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "news_post_entities" ADD CONSTRAINT "news_post_entities_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "news_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "news_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "political_videos" ADD CONSTRAINT "political_videos_news_post_id_fkey" FOREIGN KEY ("news_post_id") REFERENCES "news_posts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_likes" ADD CONSTRAINT "post_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_likes" ADD CONSTRAINT "post_likes_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "news_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_bookmarks" ADD CONSTRAINT "user_bookmarks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_bookmarks" ADD CONSTRAINT "user_bookmarks_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "news_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_preferred_categories" ADD CONSTRAINT "user_preferred_categories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_preferred_categories" ADD CONSTRAINT "user_preferred_categories_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;
