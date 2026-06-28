-- Phase 2 hyperlocal: mandal gazetteer, saved locations, story mandal tags

ALTER TABLE "news_posts" ADD COLUMN IF NOT EXISTS "location_mandal" VARCHAR(120);

CREATE INDEX IF NOT EXISTS "news_posts_location_mandal_status_idx"
  ON "news_posts"("location_mandal", "status");

CREATE TABLE IF NOT EXISTS "geo_mandals" (
    "id" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "slug" VARCHAR(140) NOT NULL,
    "district" VARCHAR(120) NOT NULL,
    "state" VARCHAR(80) NOT NULL,
    "aliases" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "geo_mandals_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "geo_mandals_slug_district_state_key"
  ON "geo_mandals"("slug", "district", "state");
CREATE INDEX IF NOT EXISTS "geo_mandals_district_state_idx"
  ON "geo_mandals"("district", "state");
CREATE INDEX IF NOT EXISTS "geo_mandals_state_idx"
  ON "geo_mandals"("state");

CREATE TABLE IF NOT EXISTS "user_saved_locations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "slot" INTEGER NOT NULL,
    "label" VARCHAR(40) NOT NULL DEFAULT 'Home',
    "city" VARCHAR(120),
    "district" VARCHAR(120),
    "mandal" VARCHAR(120),
    "state" VARCHAR(80),
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_saved_locations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "user_saved_locations_user_id_slot_key"
  ON "user_saved_locations"("user_id", "slot");
CREATE INDEX IF NOT EXISTS "user_saved_locations_user_id_idx"
  ON "user_saved_locations"("user_id");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_saved_locations_user_id_fkey'
  ) THEN
    ALTER TABLE "user_saved_locations"
      ADD CONSTRAINT "user_saved_locations_user_id_fkey"
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;
