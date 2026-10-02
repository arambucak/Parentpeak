-- AlterTable
ALTER TABLE "Event" ADD COLUMN "ageGroups" TEXT[] DEFAULT ARRAY[]::TEXT[];
