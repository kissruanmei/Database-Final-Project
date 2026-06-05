-- ============================================================
-- 校园机动车综合管理平台 - 视图定义
-- ============================================================

USE CampusVehicleDB;
GO

-- ============================================================
-- 视图 1：车主违规历史视图
-- 用途：查询某车主名下所有车辆的违规记录
-- ============================================================
IF OBJECT_ID('vw_OwnerViolationHistory', 'V') IS NOT NULL
    DROP VIEW vw_OwnerViolationHistory;
GO

CREATE VIEW vw_OwnerViolationHistory
AS
SELECT
    o.owner_id          AS 车主编号,
    o.owner_name        AS 车主姓名,
    o.owner_type        AS 车主类型,
    o.department        AS 所属部门,
    v.plate_number      AS 车牌号,
    v.vehicle_type      AS 车辆类型,
    vi.violation_id     AS 违规编号,
    vi.violation_type   AS 违规类型,
    vi.violation_time   AS 违规时间,
    vi.violation_location AS 违规地点,
    vi.violation_desc   AS 违规描述,
    vi.points_deducted  AS 扣减分数,
    a.admin_name        AS 录入管理员
FROM Owner o
JOIN Vehicle v ON o.owner_id = v.owner_id
JOIN Violation vi ON v.plate_number = vi.plate_number
JOIN Admin a ON vi.admin_id = a.admin_id;
GO

-- ============================================================
-- 视图 2：本月违规统计视图
-- 用途：统计当月各类型违规的数量和扣分情况
-- ============================================================
IF OBJECT_ID('vw_MonthlyViolationStats', 'V') IS NOT NULL
    DROP VIEW vw_MonthlyViolationStats;
GO

CREATE VIEW vw_MonthlyViolationStats
AS
SELECT
    YEAR(violation_time)    AS 年份,
    MONTH(violation_time)   AS 月份,
    violation_type          AS 违规类型,
    COUNT(*)                AS 违规次数,
    SUM(points_deducted)    AS 总扣分
FROM Violation
WHERE YEAR(violation_time) = YEAR(GETDATE())
  AND MONTH(violation_time) = MONTH(GETDATE())
GROUP BY YEAR(violation_time), MONTH(violation_time), violation_type;
GO

-- ============================================================
-- 视图 3：车辆通行证状态视图
-- 用途：查看所有车辆及其当前通行证状态
-- ============================================================
IF OBJECT_ID('vw_VehiclePermitStatus', 'V') IS NOT NULL
    DROP VIEW vw_VehiclePermitStatus;
GO

CREATE VIEW vw_VehiclePermitStatus
AS
SELECT
    v.plate_number      AS 车牌号,
    v.vehicle_type      AS 车辆类型,
    v.vehicle_color     AS 车辆颜色,
    o.owner_name        AS 车主姓名,
    o.owner_type        AS 车主类型,
    p.permit_id         AS 通行证编号,
    p.permit_type       AS 权限类型,
    p.start_date        AS 生效日期,
    p.end_date          AS 到期日期,
    p.permit_status     AS 通行证状态,
    CASE
        WHEN p.end_date < GETDATE() THEN N'已过期'
        WHEN DATEDIFF(DAY, GETDATE(), p.end_date) <= 30 THEN N'即将过期'
        ELSE N'正常'
    END                 AS 有效期状态,
    a.admin_name        AS 审批管理员
FROM Vehicle v
JOIN Owner o ON v.owner_id = o.owner_id
LEFT JOIN Permit p ON v.plate_number = p.plate_number AND p.permit_status = N'有效'
LEFT JOIN Admin a ON p.admin_id = a.admin_id;
GO

-- ============================================================
-- 视图 4：待处理处罚视图
-- 用途：查询所有待处理的处罚记录
-- ============================================================
IF OBJECT_ID('vw_PendingPenalties', 'V') IS NOT NULL
    DROP VIEW vw_PendingPenalties;
GO

CREATE VIEW vw_PendingPenalties
AS
SELECT
    pe.penalty_id       AS 处罚编号,
    pe.penalty_type     AS 处罚类型,
    pe.penalty_amount   AS 罚款金额,
    pe.penalty_status   AS 处罚状态,
    vi.violation_id     AS 违规编号,
    vi.violation_type   AS 违规类型,
    vi.violation_time   AS 违规时间,
    vi.violation_location AS 违规地点,
    v.plate_number      AS 车牌号,
    o.owner_name        AS 车主姓名,
    o.phone             AS 联系电话
FROM Penalty pe
JOIN Violation vi ON pe.violation_id = vi.violation_id
JOIN Vehicle v ON vi.plate_number = v.plate_number
JOIN Owner o ON v.owner_id = o.owner_id
WHERE pe.penalty_status = N'待处理';
GO

-- ============================================================
-- 视图 5：车主积分排名视图
-- 用途：按违规积分从高到低排名，积分相同时按姓名排序
-- ============================================================
IF OBJECT_ID('vw_OwnerPointsRanking', 'V') IS NOT NULL
    DROP VIEW vw_OwnerPointsRanking;
GO

CREATE VIEW vw_OwnerPointsRanking
AS
SELECT
    o.owner_id          AS 车主编号,
    o.owner_name        AS 车主姓名,
    o.owner_type        AS 车主类型,
    o.department        AS 所属部门,
    o.total_points      AS 累计扣分,
    COUNT(v.plate_number) AS 车辆数量,
    COUNT(vi.violation_id) AS 违规次数,
    CASE
        WHEN o.total_points >= 12 THEN N'通行证暂停'
        WHEN o.total_points >= 9 THEN N'警告'
        WHEN o.total_points >= 6 THEN N'注意'
        ELSE N'正常'
    END                 AS 风险等级
FROM Owner o
LEFT JOIN Vehicle v ON o.owner_id = v.owner_id
LEFT JOIN Violation vi ON v.plate_number = vi.plate_number
GROUP BY o.owner_id, o.owner_name, o.owner_type, o.department, o.total_points;
GO

-- ============================================================
-- 视图 6：学院违规统计视图
-- 用途：按学院/部门统计违规情况
-- ============================================================
IF OBJECT_ID('vw_DepartmentViolationStats', 'V') IS NOT NULL
    DROP VIEW vw_DepartmentViolationStats;
GO

CREATE VIEW vw_DepartmentViolationStats
AS
SELECT
    ISNULL(o.department, N'临时访客') AS 部门,
    COUNT(DISTINCT o.owner_id)       AS 车主人数,
    COUNT(vi.violation_id)           AS 违规次数,
    SUM(vi.points_deducted)          AS 总扣分
FROM Owner o
JOIN Vehicle v ON o.owner_id = v.owner_id
JOIN Violation vi ON v.plate_number = vi.plate_number
GROUP BY o.department;
GO

PRINT '===== 视图创建完成 =====';
PRINT '1. vw_OwnerViolationHistory - 车主违规历史视图';
PRINT '2. vw_MonthlyViolationStats - 本月违规统计视图';
PRINT '3. vw_VehiclePermitStatus - 车辆通行证状态视图';
PRINT '4. vw_PendingPenalties - 待处理处罚视图';
PRINT '5. vw_OwnerPointsRanking - 车主积分排名视图';
PRINT '6. vw_DepartmentViolationStats - 学院违规统计视图';
GO
