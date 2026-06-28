CREATE TABLE "user_publisher_follows" (
    "user_id" UUID NOT NULL,
    "publisher_key" VARCHAR(120) NOT NULL,
    "publisher_name" VARCHAR(200) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_publisher_follows_pkey" PRIMARY KEY ("user_id","publisher_key")
);

CREATE INDEX "user_publisher_follows_user_id_created_at_idx" ON "user_publisher_follows"("user_id", "created_at");

ALTER TABLE "user_publisher_follows" ADD CONSTRAINT "user_publisher_follows_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
