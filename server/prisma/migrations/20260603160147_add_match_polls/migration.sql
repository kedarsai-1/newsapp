-- CreateTable
CREATE TABLE "match_polls" (
    "id" UUID NOT NULL,
    "match_id" TEXT NOT NULL,
    "option_a_title" TEXT NOT NULL,
    "option_b_title" TEXT NOT NULL,
    "votes_a" INTEGER NOT NULL DEFAULT 0,
    "votes_b" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "match_polls_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "match_poll_votes" (
    "id" UUID NOT NULL,
    "poll_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "option" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "match_poll_votes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "match_polls_match_id_key" ON "match_polls"("match_id");

-- CreateIndex
CREATE UNIQUE INDEX "match_poll_votes_poll_id_user_id_key" ON "match_poll_votes"("poll_id", "user_id");

-- CreateIndex
CREATE INDEX "news_posts_summary_fingerprint_idx" ON "news_posts"("summary_fingerprint");

-- CreateIndex
CREATE INDEX "news_posts_language_status_source_published_at_idx" ON "news_posts"("language", "status", "source_published_at");

-- CreateIndex
CREATE INDEX "news_posts_status_source_published_at_idx" ON "news_posts"("status", "source_published_at");

-- CreateIndex
CREATE INDEX "news_posts_constituency_status_source_published_at_idx" ON "news_posts"("constituency", "status", "source_published_at");

-- CreateIndex
CREATE INDEX "news_posts_location_city_status_source_published_at_idx" ON "news_posts"("location_city", "status", "source_published_at");

-- AddForeignKey
ALTER TABLE "match_poll_votes" ADD CONSTRAINT "match_poll_votes_poll_id_fkey" FOREIGN KEY ("poll_id") REFERENCES "match_polls"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_poll_votes" ADD CONSTRAINT "match_poll_votes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
