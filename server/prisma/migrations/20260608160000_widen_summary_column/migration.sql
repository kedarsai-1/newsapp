-- Allow full AI summaries (was VARCHAR(300), clipped mid-sentence in article detail).
ALTER TABLE "NewsPost" ALTER COLUMN "summary" TYPE VARCHAR(2000);
