-- Short share links (/n/{code}) — Dailyhunt-style branded sharing
ALTER TABLE "news_posts" ADD COLUMN "share_code" VARCHAR(12);

CREATE UNIQUE INDEX "news_posts_share_code_key" ON "news_posts"("share_code");
