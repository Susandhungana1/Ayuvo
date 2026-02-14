/*
  Warnings:

  - You are about to drop the column `doctorId` on the `Blog` table. All the data in the column will be lost.
  - Added the required column `authorId` to the `Blog` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "Blog" DROP CONSTRAINT "Blog_doctorId_fkey";

-- DropIndex
DROP INDEX "Blog_doctorId_idx";

-- AlterTable
ALTER TABLE "Blog" DROP COLUMN "doctorId",
ADD COLUMN     "address" TEXT,
ADD COLUMN     "authorId" TEXT NOT NULL,
ADD COLUMN     "city" TEXT,
ADD COLUMN     "isEmergency" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "latitude" DOUBLE PRECISION,
ADD COLUMN     "longitude" DOUBLE PRECISION,
ALTER COLUMN "published" SET DEFAULT true;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "address" TEXT,
ADD COLUMN     "city" TEXT,
ADD COLUMN     "latitude" DOUBLE PRECISION,
ADD COLUMN     "longitude" DOUBLE PRECISION;

-- CreateIndex
CREATE INDEX "Blog_authorId_idx" ON "Blog"("authorId");

-- CreateIndex
CREATE INDEX "Blog_isEmergency_idx" ON "Blog"("isEmergency");

-- CreateIndex
CREATE INDEX "Blog_city_idx" ON "Blog"("city");

-- CreateIndex
CREATE INDEX "User_city_idx" ON "User"("city");

-- AddForeignKey
ALTER TABLE "Blog" ADD CONSTRAINT "Blog_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
