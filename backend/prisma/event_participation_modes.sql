BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
ALTER TABLE "Event" ADD COLUMN IF NOT EXISTS "participationMode" TEXT NOT NULL DEFAULT 'legacyApproval';
ALTER TABLE "Event" ADD COLUMN IF NOT EXISTS "externalUrl" TEXT;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'Event_participationMode_check'
      AND conrelid = '"Event"'::regclass
  ) THEN
    ALTER TABLE "Event" ADD CONSTRAINT "Event_participationMode_check"
      CHECK ("participationMode" IN ('legacyApproval', 'direct', 'interest'));
  END IF;
END $$;
COMMIT;