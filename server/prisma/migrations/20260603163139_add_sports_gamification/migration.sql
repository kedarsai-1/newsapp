-- AlterTable
ALTER TABLE "match_poll_votes" ADD COLUMN     "is_correct" BOOLEAN,
ADD COLUMN     "is_processed" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "match_polls" ADD COLUMN     "is_resolved" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "winner_option" TEXT;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "max_prediction_streak" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "points" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "prediction_streak" INTEGER NOT NULL DEFAULT 0;
