CREATE TABLE "FeatureQuota" (
    "userId" TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
    "feature" TEXT NOT NULL,
    "periodStart" TIMESTAMPTZ NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0 CHECK ("count" >= 0),
    PRIMARY KEY ("userId", "feature", "periodStart")
);

CREATE TABLE "FeatureQuotaItem" (
    "id" TEXT PRIMARY KEY,
    "userId" TEXT NOT NULL,
    "feature" TEXT NOT NULL,
    "periodStart" TIMESTAMPTZ NOT NULL,
    "itemKey" TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ NOT NULL,
    "aiUsed" BOOLEAN NOT NULL DEFAULT false,
    "result" JSONB,
    FOREIGN KEY ("userId", "feature", "periodStart")
        REFERENCES "FeatureQuota"("userId", "feature", "periodStart") ON DELETE CASCADE,
    UNIQUE ("userId", "feature", "periodStart", "itemKey")
);

CREATE TABLE "DiscoveredEventDetail" (
    "id" TEXT PRIMARY KEY,
    "data" JSONB NOT NULL
);
