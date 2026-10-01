-- CreateTable
CREATE TABLE "AiMemorySettings" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiMemorySettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiChildProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "birthDate" TIMESTAMP(3),
    "gender" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiChildProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AiMemoryItem" (
    "id" TEXT NOT NULL,
    "childId" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'confirmed',
    "userConfirmedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiMemoryItem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AiMemorySettings_userId_key" ON "AiMemorySettings"("userId");
CREATE INDEX "AiChildProfile_userId_idx" ON "AiChildProfile"("userId");
CREATE INDEX "AiChildProfile_userId_updatedAt_idx" ON "AiChildProfile"("userId", "updatedAt");
CREATE UNIQUE INDEX "AiMemoryItem_childId_category_key_key" ON "AiMemoryItem"("childId", "category", "key");
CREATE INDEX "AiMemoryItem_childId_status_idx" ON "AiMemoryItem"("childId", "status");

-- AddForeignKey
ALTER TABLE "AiMemoryItem"
ADD CONSTRAINT "AiMemoryItem_childId_fkey"
FOREIGN KEY ("childId") REFERENCES "AiChildProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
