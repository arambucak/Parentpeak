-- Adult age is not required for playmate matching.
ALTER TABLE "ParentMatchingProfile" ALTER COLUMN "age" DROP NOT NULL;
