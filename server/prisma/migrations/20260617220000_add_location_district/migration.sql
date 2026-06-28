-- AlterTable
ALTER TABLE "news_posts" ADD COLUMN IF NOT EXISTS "location_district" VARCHAR(120);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "news_posts_location_district_status_idx"
  ON "news_posts"("location_district", "status");
