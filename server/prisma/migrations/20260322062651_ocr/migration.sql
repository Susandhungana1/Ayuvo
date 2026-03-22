/*
  Warnings:

  - The values [PRESCRIPTION] on the enum `FileType` will be removed. If these variants are still used in the database, this will fail.
  - The values [OTHER] on the enum `MedicalReportType` will be removed. If these variants are still used in the database, this will fail.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "FileType_new" AS ENUM ('DOCTOR_TICKET', 'MEDICINES', 'MEDICAL_REPORTS', 'OTHER');
ALTER TABLE "MedicalFile" ALTER COLUMN "fileType" TYPE "FileType_new" USING ("fileType"::text::"FileType_new");
ALTER TYPE "FileType" RENAME TO "FileType_old";
ALTER TYPE "FileType_new" RENAME TO "FileType";
DROP TYPE "public"."FileType_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "MedicalReportType_new" AS ENUM ('BLOOD_TEST', 'URINE_TEST', 'STOOL_TEST', 'XRAY', 'MRI', 'CT_SCAN', 'ECG', 'ULTRASOUND', 'LAB_REPORT', 'OTHERS');
ALTER TABLE "MedicalReport" ALTER COLUMN "reportType" TYPE "MedicalReportType_new" USING ("reportType"::text::"MedicalReportType_new");
ALTER TYPE "MedicalReportType" RENAME TO "MedicalReportType_old";
ALTER TYPE "MedicalReportType_new" RENAME TO "MedicalReportType";
DROP TYPE "public"."MedicalReportType_old";
COMMIT;

-- AlterTable
ALTER TABLE "MedicalReport" ADD COLUMN     "extractedText" TEXT;
