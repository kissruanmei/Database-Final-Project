-- ============================================================
-- 校园机动车综合管理平台 - 建库建表脚本
-- 使用方法：在 SSMS 中选择 CampusVehicleDB 数据库后执行本脚本
-- 或使用 sqlcmd: sqlcmd -S localhost -E -C -d CampusVehicleDB -i 01_create_tables.sql
-- ============================================================

USE CampusVehicleDB;
GO

-- ============================================================
-- 先清理旧表（按依赖关系反序删除）
-- ============================================================
IF OBJECT_ID('Penalty', 'U') IS NOT NULL DROP TABLE Penalty;
IF OBJECT_ID('Violation', 'U') IS NOT NULL DROP TABLE Violation;
IF OBJECT_ID('Permit', 'U') IS NOT NULL DROP TABLE Permit;
IF OBJECT_ID('Vehicle', 'U') IS NOT NULL DROP TABLE Vehicle;
IF OBJECT_ID('Owner', 'U') IS NOT NULL DROP TABLE Owner;
IF OBJECT_ID('Admin', 'U') IS NOT NULL DROP TABLE Admin;
GO

-- ============================================================
-- 表 1：管理员表（Admin）
-- ============================================================
CREATE TABLE Admin (
    admin_id        INT           IDENTITY(1,1) PRIMARY KEY,
    admin_name      VARCHAR(50)   NOT NULL UNIQUE,
    admin_password  VARCHAR(64)   NOT NULL
);
GO

-- ============================================================
-- 表 2：车主信息表（Owner）
-- ============================================================
CREATE TABLE Owner (
    owner_id        INT           IDENTITY(1,1) PRIMARY KEY,
    owner_name      VARCHAR(50)   NOT NULL,
    owner_type      VARCHAR(20)   NOT NULL
                      CHECK (owner_type IN (N'教职工', N'学生', N'临时访客')),
    id_card         VARCHAR(18)   NOT NULL UNIQUE,
    phone           VARCHAR(11)   NOT NULL,
    department      VARCHAR(100),
    total_points    INT           NOT NULL DEFAULT 0
                      CHECK (total_points >= 0)
);
GO

-- ============================================================
-- 表 3：车辆信息表（Vehicle）
-- ============================================================
CREATE TABLE Vehicle (
    plate_number    VARCHAR(10)   PRIMARY KEY,
    vehicle_type    VARCHAR(20)   NOT NULL
                      CHECK (vehicle_type IN (N'小型汽车', N'大型汽车', N'摩托车')),
    vehicle_color   VARCHAR(10)   NOT NULL,
    owner_id        INT           NOT NULL
                      REFERENCES Owner(owner_id) ON DELETE CASCADE
);
GO

-- ============================================================
-- 表 4：通行证表（Permit）
-- ============================================================
CREATE TABLE Permit (
    permit_id       INT           IDENTITY(1,1) PRIMARY KEY,
    plate_number    VARCHAR(10)   NOT NULL
                      REFERENCES Vehicle(plate_number) ON DELETE CASCADE,
    permit_type     VARCHAR(20)   NOT NULL
                      CHECK (permit_type IN (N'全校通行', N'限时通行', N'指定区域')),
    start_date      DATE          NOT NULL,
    end_date        DATE          NOT NULL,
    permit_status   VARCHAR(10)   NOT NULL DEFAULT N'有效'
                      CHECK (permit_status IN (N'有效', N'过期', N'注销')),
    admin_id        INT           NOT NULL
                      REFERENCES Admin(admin_id),
    CONSTRAINT chk_permit_date CHECK (end_date > start_date)
);
GO

-- ============================================================
-- 表 5：违规记录表（Violation）
-- ============================================================
CREATE TABLE Violation (
    violation_id        INT           IDENTITY(1,1) PRIMARY KEY,
    plate_number        VARCHAR(10)   NOT NULL
                          REFERENCES Vehicle(plate_number) ON DELETE CASCADE,
    violation_type      VARCHAR(50)   NOT NULL,
    violation_time      DATETIME      NOT NULL,
    violation_location  VARCHAR(100)  NOT NULL,
    violation_desc      TEXT,
    points_deducted     INT           NOT NULL
                          CHECK (points_deducted > 0),
    admin_id            INT           NOT NULL
                          REFERENCES Admin(admin_id)
);
GO

-- ============================================================
-- 表 6：处罚记录表（Penalty）
-- ============================================================
CREATE TABLE Penalty (
    penalty_id      INT           IDENTITY(1,1) PRIMARY KEY,
    violation_id    INT           NOT NULL UNIQUE
                      REFERENCES Violation(violation_id) ON DELETE CASCADE,
    penalty_type    VARCHAR(50)   NOT NULL
                      CHECK (penalty_type IN (N'警告', N'罚款', N'暂停通行证', N'禁止入校')),
    penalty_amount  DECIMAL(10,2) DEFAULT 0
                      CHECK (penalty_amount >= 0),
    penalty_status  VARCHAR(10)   NOT NULL DEFAULT N'待处理'
                      CHECK (penalty_status IN (N'待处理', N'已处理', N'已申诉', N'申诉通过')),
    process_time    DATETIME,
    admin_id        INT
                      REFERENCES Admin(admin_id)
);
GO

-- ============================================================
-- 索引（为高频查询字段加速）
-- ============================================================
CREATE INDEX idx_vehicle_owner ON Vehicle(owner_id);
CREATE INDEX idx_violation_plate ON Violation(plate_number);
CREATE INDEX idx_violation_time ON Violation(violation_time);
CREATE INDEX idx_penalty_status ON Penalty(penalty_status);
CREATE INDEX idx_permit_plate_status ON Permit(plate_number, permit_status);
GO

PRINT '===== 建库建表完成 =====';
GO
