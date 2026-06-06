-- CreateTable
CREATE TABLE "post_seen" (
    "user_id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_seen_pkey" PRIMARY KEY ("user_id","post_id")
);

-- CreateIndex
CREATE INDEX "post_seen_post_id_idx" ON "post_seen"("post_id");

-- CreateIndex
CREATE INDEX "post_seen_user_id_created_at_idx" ON "post_seen"("user_id", "created_at");

-- AddForeignKey
ALTER TABLE "post_seen" ADD CONSTRAINT "post_seen_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_seen" ADD CONSTRAINT "post_seen_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "news_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
