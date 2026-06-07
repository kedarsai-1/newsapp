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
