CREATE TABLE "AdsConsent" (
    "userId" TEXT NOT NULL,
    "decision" TEXT NOT NULL DEFAULT 'unknown',
    "consentVersion" TEXT NOT NULL DEFAULT 'ads.consent.v1',
    "consentRevision" TEXT NOT NULL,
    "consentedAt" TIMESTAMP(3),
    "withdrawnAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AdsConsent_pkey" PRIMARY KEY ("userId"),
    CONSTRAINT "AdsConsent_decision_check" CHECK ("decision" IN ('unknown', 'denied', 'granted')),
    CONSTRAINT "AdsConsent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
