/*
  Warnings:

  - You are about to drop the column `createdBy` on the `project` table. All the data in the column will be lost.
  - You are about to drop the column `projectName` on the `project` table. All the data in the column will be lost.
  - You are about to drop the column `startDate` on the `project` table. All the data in the column will be lost.
  - You are about to drop the column `projectId` on the `projectmembership` table. All the data in the column will be lost.
  - You are about to drop the column `role` on the `projectmembership` table. All the data in the column will be lost.
  - You are about to drop the column `userId` on the `projectmembership` table. All the data in the column will be lost.
  - You are about to drop the column `projectId` on the `stage` table. All the data in the column will be lost.
  - You are about to drop the column `stageName` on the `stage` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[project_id,user_id,role_id]` on the table `ProjectMembership` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `created_by` to the `Project` table without a default value. This is not possible if the table is not empty.
  - Added the required column `project_name` to the `Project` table without a default value. This is not possible if the table is not empty.
  - Added the required column `start_date` to the `Project` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updatedAt` to the `Project` table without a default value. This is not possible if the table is not empty.
  - Added the required column `project_id` to the `ProjectMembership` table without a default value. This is not possible if the table is not empty.
  - Added the required column `role_id` to the `ProjectMembership` table without a default value. This is not possible if the table is not empty.
  - Added the required column `user_id` to the `ProjectMembership` table without a default value. This is not possible if the table is not empty.
  - Added the required column `project_id` to the `Stage` table without a default value. This is not possible if the table is not empty.
  - Added the required column `stage_name` to the `Stage` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updatedAt` to the `Stage` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updatedAt` to the `User` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE `project` DROP FOREIGN KEY `Project_createdBy_fkey`;

-- DropForeignKey
ALTER TABLE `projectmembership` DROP FOREIGN KEY `ProjectMembership_projectId_fkey`;

-- DropForeignKey
ALTER TABLE `projectmembership` DROP FOREIGN KEY `ProjectMembership_userId_fkey`;

-- DropForeignKey
ALTER TABLE `stage` DROP FOREIGN KEY `Stage_projectId_fkey`;

-- DropIndex
DROP INDEX `ProjectMembership_userId_projectId_key` ON `projectmembership`;

-- AlterTable
ALTER TABLE `project` DROP COLUMN `createdBy`,
    DROP COLUMN `projectName`,
    DROP COLUMN `startDate`,
    ADD COLUMN `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ADD COLUMN `created_by` CHAR(24) NULL,
    ADD COLUMN `description` TEXT NULL,
    ADD COLUMN `end_date` DATETIME(3) NULL,
    ADD COLUMN `internal_order_no` VARCHAR(191) NULL,
    ADD COLUMN `isReviewApplicable` VARCHAR(191) NULL,
    ADD COLUMN `overallDefectRate` DOUBLE NULL,
    ADD COLUMN `priority` VARCHAR(191) NOT NULL DEFAULT 'medium',
    ADD COLUMN `project_name` VARCHAR(191) NOT NULL DEFAULT '',
    ADD COLUMN `project_no` VARCHAR(191) NULL,
    ADD COLUMN `reviewApplicableRemark` TEXT NULL,
    ADD COLUMN `start_date` DATETIME(3) NULL,
    ADD COLUMN `templateName` VARCHAR(191) NULL,
    ADD COLUMN `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    MODIFY `status` VARCHAR(191) NOT NULL DEFAULT 'pending';

-- AlterTable
ALTER TABLE `projectmembership` DROP COLUMN `projectId`,
    DROP COLUMN `role`,
    DROP COLUMN `userId`,
    ADD COLUMN `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ADD COLUMN `project_id` CHAR(24) NOT NULL DEFAULT '',
    ADD COLUMN `role_id` CHAR(24) NOT NULL DEFAULT '',
    ADD COLUMN `user_id` CHAR(24) NOT NULL DEFAULT '';

-- AlterTable
ALTER TABLE `stage` DROP COLUMN `projectId`,
    DROP COLUMN `stageName`,
    ADD COLUMN `conflict_count` INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ADD COLUMN `created_by` CHAR(24) NULL,
    ADD COLUMN `description` TEXT NULL,
    ADD COLUMN `loopback_count` INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN `project_id` CHAR(24) NOT NULL DEFAULT '',
    ADD COLUMN `stage_key` VARCHAR(191) NULL,
    ADD COLUMN `stage_name` VARCHAR(191) NOT NULL DEFAULT '',
    ADD COLUMN `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    MODIFY `status` VARCHAR(191) NOT NULL DEFAULT 'pending';

-- AlterTable
ALTER TABLE `user` ADD COLUMN `accessToken` TEXT NULL,
    ADD COLUMN `role` VARCHAR(191) NOT NULL DEFAULT 'user',
    ADD COLUMN `status` VARCHAR(191) NOT NULL DEFAULT 'active',
    ADD COLUMN `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3);

-- CreateTable
CREATE TABLE `Role` (
    `id` CHAR(24) NOT NULL,
    `role_name` VARCHAR(191) NOT NULL,
    `description` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    UNIQUE INDEX `Role_role_name_key`(`role_name`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Checklist` (
    `id` CHAR(24) NOT NULL,
    `stage_id` CHAR(24) NOT NULL,
    `created_by` CHAR(24) NOT NULL,
    `status` VARCHAR(191) NOT NULL DEFAULT 'draft',
    `revision_number` INTEGER NOT NULL DEFAULT 0,
    `checklist_name` VARCHAR(191) NOT NULL,
    `description` TEXT NULL,
    `defectCategory` VARCHAR(191) NULL DEFAULT '',
    `defectSeverity` VARCHAR(191) NULL DEFAULT '',
    `remark` TEXT NULL,
    `answers` JSON NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    INDEX `Checklist_stage_id_idx`(`stage_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Checkpoint` (
    `id` CHAR(24) NOT NULL,
    `checklistId` CHAR(24) NOT NULL,
    `question` TEXT NOT NULL,
    `categoryId` VARCHAR(191) NULL,
    `executorResponse` JSON NULL,
    `reviewerResponse` JSON NULL,
    `defect` JSON NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `Checkpoint_checklistId_idx`(`checklistId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ChecklistAnswer` (
    `id` CHAR(24) NOT NULL,
    `project_id` CHAR(24) NOT NULL,
    `phase` INTEGER NOT NULL,
    `role` VARCHAR(191) NOT NULL,
    `sub_question` TEXT NOT NULL,
    `answer` VARCHAR(191) NULL,
    `remark` TEXT NULL,
    `images` JSON NULL,
    `metadata` JSON NULL,
    `answered_by` CHAR(24) NULL,
    `answered_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `is_submitted` BOOLEAN NOT NULL DEFAULT false,
    `categoryId` VARCHAR(191) NULL DEFAULT '',
    `severity` VARCHAR(191) NULL DEFAULT '',
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    INDEX `ChecklistAnswer_project_id_phase_role_idx`(`project_id`, `phase`, `role`),
    UNIQUE INDEX `ChecklistAnswer_project_id_phase_role_sub_question_key`(`project_id`, `phase`, `role`, `sub_question`(255)),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ChecklistApproval` (
    `id` CHAR(24) NOT NULL,
    `project_id` CHAR(24) NOT NULL,
    `phase` INTEGER NOT NULL,
    `status` VARCHAR(191) NOT NULL DEFAULT 'pending',
    `requested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `decided_at` DATETIME(3) NULL,
    `decided_by` CHAR(24) NULL,
    `notes` TEXT NULL,
    `revertCount` INTEGER NOT NULL DEFAULT 0,
    `executor_submitted` BOOLEAN NOT NULL DEFAULT false,
    `executor_submitted_at` DATETIME(3) NULL,
    `reviewer_submitted` BOOLEAN NOT NULL DEFAULT false,
    `reviewer_submitted_at` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    INDEX `ChecklistApproval_project_id_phase_idx`(`project_id`, `phase`),
    UNIQUE INDEX `ChecklistApproval_project_id_phase_key`(`project_id`, `phase`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ChecklistTransaction` (
    `id` CHAR(24) NOT NULL,
    `checklist_id` CHAR(24) NOT NULL,
    `user_id` CHAR(24) NOT NULL,
    `action_type` VARCHAR(191) NOT NULL,
    `description` TEXT NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ChecklistTransaction_checklist_id_idx`(`checklist_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Template` (
    `id` CHAR(24) NOT NULL,
    `templateName` VARCHAR(191) NULL,
    `name` VARCHAR(191) NOT NULL DEFAULT 'Default Quality Review Template',
    `description` TEXT NULL,
    `isActive` BOOLEAN NOT NULL DEFAULT true,
    `stageNames` JSON NULL,
    `defectCategories` JSON NULL,
    `stageData` JSON NULL,
    `modifiedBy` CHAR(24) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `Template_templateName_key`(`templateName`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ProjectChecklist` (
    `id` CHAR(24) NOT NULL,
    `projectId` CHAR(24) NOT NULL,
    `stageId` CHAR(24) NOT NULL,
    `stage` VARCHAR(191) NOT NULL,
    `groups` JSON NULL,
    `iterations` JSON NULL,
    `currentIteration` INTEGER NOT NULL DEFAULT 1,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    INDEX `ProjectChecklist_projectId_idx`(`projectId`),
    INDEX `ProjectChecklist_stageId_idx`(`stageId`),
    UNIQUE INDEX `ProjectChecklist_projectId_stageId_key`(`projectId`, `stageId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `ProjectMembership_project_id_idx` ON `ProjectMembership`(`project_id`);

-- CreateIndex
CREATE INDEX `ProjectMembership_user_id_idx` ON `ProjectMembership`(`user_id`);

-- CreateIndex
CREATE UNIQUE INDEX `ProjectMembership_project_id_user_id_role_id_key` ON `ProjectMembership`(`project_id`, `user_id`, `role_id`);

-- CreateIndex
CREATE INDEX `Stage_project_id_idx` ON `Stage`(`project_id`);

-- CreateIndex
CREATE INDEX `Stage_project_id_stage_key_idx` ON `Stage`(`project_id`, `stage_key`);

-- Note: FK constraints skipped because legacy data in tables has empty/null values.
-- Application-level referential integrity is enforced in the service layer.
-- FKs will be added after data is migrated via a subsequent migration.

-- AddForeignKey (skipped for Checklist, ChecklistAnswer, ChecklistApproval, ChecklistTransaction, ProjectChecklist 
-- which reference tables that may have no data yet - safe to add)
ALTER TABLE `Checklist` ADD CONSTRAINT `Checklist_stage_id_fkey` FOREIGN KEY (`stage_id`) REFERENCES `Stage`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `Checkpoint` ADD CONSTRAINT `Checkpoint_checklistId_fkey` FOREIGN KEY (`checklistId`) REFERENCES `Checklist`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `ChecklistAnswer` ADD CONSTRAINT `ChecklistAnswer_answered_by_fkey` FOREIGN KEY (`answered_by`) REFERENCES `User`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `ChecklistApproval` ADD CONSTRAINT `ChecklistApproval_decided_by_fkey` FOREIGN KEY (`decided_by`) REFERENCES `User`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `ChecklistTransaction` ADD CONSTRAINT `ChecklistTransaction_checklist_id_fkey` FOREIGN KEY (`checklist_id`) REFERENCES `Checklist`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `ChecklistTransaction` ADD CONSTRAINT `ChecklistTransaction_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
