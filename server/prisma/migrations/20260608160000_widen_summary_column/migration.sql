-- Allow full AI summaries (was VARCHAR(300), clipped mid-sentence in article detail).
ALTER TABLE "news_posts" ALTER COLUMN "summary" TYPE VARCHAR(2000);
