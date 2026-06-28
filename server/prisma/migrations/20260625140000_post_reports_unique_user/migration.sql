-- One report per authenticated user per post.
CREATE UNIQUE INDEX IF NOT EXISTS "post_reports_post_id_user_id_key"
  ON "post_reports" ("post_id", "user_id")
  WHERE "user_id" IS NOT NULL;
