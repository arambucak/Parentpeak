-- Verification flags already written by server.js and created at runtime by
-- ensureParentMatchingSchemaReady(). Idempotent: no data change, no DROP, no UPDATE.
ALTER TABLE "ParentMatchingProfile" ADD COLUMN IF NOT EXISTS "phoneVerified" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "ParentMatchingProfile" ADD COLUMN IF NOT EXISTS "identityVerified" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "ParentMatchingProfile" ADD COLUMN IF NOT EXISTS "moderationChecked" BOOLEAN NOT NULL DEFAULT false;
