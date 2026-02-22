/*
  Warnings:

  - You are about to drop the column `created_at` on the `Blog` table. All the data in the column will be lost.
  - You are about to drop the column `updated_at` on the `Blog` table. All the data in the column will be lost.
  - You are about to drop the column `created_at` on the `BlogLike` table. All the data in the column will be lost.
  - You are about to drop the column `created_at` on the `BlogShare` table. All the data in the column will be lost.
  - You are about to drop the column `created_at` on the `Comment` table. All the data in the column will be lost.
  - You are about to drop the column `deletedAt` on the `Comment` table. All the data in the column will be lost.
  - You are about to drop the column `updated_at` on the `Comment` table. All the data in the column will be lost.
  - You are about to drop the column `created_at` on the `Doctor` table. All the data in the column will be lost.
  - You are about to drop the column `updated_at` on the `Doctor` table. All the data in the column will be lost.
  - You are about to drop the column `created_at` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `updated_at` on the `User` table. All the data in the column will be lost.
  - Added the required column `updatedAt` to the `Blog` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updatedAt` to the `User` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "FileType" AS ENUM ('DOCTOR_TICKET', 'PRESCRIPTION', 'OTHER');

-- CreateEnum
CREATE TYPE "MedicalReportType" AS ENUM ('BLOOD_TEST', 'URINE_TEST', 'STOOL_TEST', 'XRAY', 'MRI', 'CT_SCAN', 'ECG', 'ULTRASOUND', 'LAB_REPORT', 'OTHER');

-- DropIndex
DROP INDEX "Blog_authorId_idx";

-- DropIndex
DROP INDEX "Blog_created_at_idx";

-- DropIndex
DROP INDEX "BlogLike_userId_idx";

-- DropIndex
DROP INDEX "BlogShare_blogId_idx";

-- DropIndex
DROP INDEX "BlogShare_userId_idx";

-- DropIndex
DROP INDEX "Comment_blogId_idx";

-- DropIndex
DROP INDEX "Comment_parentId_idx";

-- DropIndex
DROP INDEX "Comment_userId_idx";

-- AlterTable
ALTER TABLE "Blog" DROP COLUMN "created_at",
DROP COLUMN "updated_at",
ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;

-- AlterTable
ALTER TABLE "BlogLike" DROP COLUMN "created_at";

-- AlterTable
ALTER TABLE "BlogShare" DROP COLUMN "created_at";

-- AlterTable
ALTER TABLE "Comment" DROP COLUMN "created_at",
DROP COLUMN "deletedAt",
DROP COLUMN "updated_at",
ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- AlterTable
ALTER TABLE "Doctor" DROP COLUMN "created_at",
DROP COLUMN "updated_at";

-- AlterTable
ALTER TABLE "User" DROP COLUMN "created_at",
DROP COLUMN "updated_at",
ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;

-- CreateTable
CREATE TABLE "MedicalDocument" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "hospital" TEXT NOT NULL,
    "location" TEXT,
    "doctorName" TEXT,
    "department" TEXT,
    "description" TEXT,
    "checkupDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "MedicalDocument_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Medicine" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "imageUrl" TEXT,
    "documentId" TEXT NOT NULL,

    CONSTRAINT "Medicine_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MedicalFile" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "fileType" "FileType" NOT NULL,
    "documentId" TEXT NOT NULL,
    "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MedicalFile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MedicalReport" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "documentId" TEXT,
    "reportType" "MedicalReportType" NOT NULL,
    "reportDate" TIMESTAMP(3),
    "fileUrl" TEXT NOT NULL,
    "thumbnail" TEXT,
    "notes" TEXT,
    "resultSummary" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MedicalReport_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MedicalDocument_userId_idx" ON "MedicalDocument"("userId");

-- CreateIndex
CREATE INDEX "MedicalDocument_checkupDate_idx" ON "MedicalDocument"("checkupDate");

-- CreateIndex
CREATE INDEX "MedicalReport_userId_idx" ON "MedicalReport"("userId");

-- CreateIndex
CREATE INDEX "MedicalReport_reportType_idx" ON "MedicalReport"("reportType");

-- CreateIndex
CREATE INDEX "MedicalReport_reportDate_idx" ON "MedicalReport"("reportDate");

-- AddForeignKey
ALTER TABLE "MedicalDocument" ADD CONSTRAINT "MedicalDocument_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Medicine" ADD CONSTRAINT "Medicine_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "MedicalDocument"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MedicalFile" ADD CONSTRAINT "MedicalFile_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "MedicalDocument"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MedicalReport" ADD CONSTRAINT "MedicalReport_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MedicalReport" ADD CONSTRAINT "MedicalReport_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "MedicalDocument"("id") ON DELETE CASCADE ON UPDATE CASCADE;
