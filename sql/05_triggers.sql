-- ============================================================
-- 校园机动车综合管理平台 - 触发器
-- ============================================================

USE CampusVehicleDB;
GO

-- ============================================================
-- 触发器 1：违规记录插入后自动更新车主积分
-- 用途：当插入新的违规记录时，自动更新车主的累计积分
-- 注意：该逻辑已在存储过程 sp_AddViolation 中实现，此触发器为备用方案
-- ============================================================
IF OBJECT_ID('tr_AfterInsertViolation', 'TR') IS NOT NULL
    DROP TRIGGER tr_AfterInsertViolation;
GO

CREATE TRIGGER tr_AfterInsertViolation
ON Violation
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- 更新车主积分
    UPDATE o
    SET o.total_points = o.total_points + i.points_deducted
    FROM Owner o
    JOIN Vehicle v ON o.owner_id = v.owner_id
    JOIN inserted i ON v.plate_number = i.plate_number;

    -- 检查是否有车主积分达到12分，自动暂停通行证
    UPDATE p
    SET p.permit_status = N'注销'
    FROM Permit p
    JOIN Vehicle v ON p.plate_number = v.plate_number
    JOIN Owner o ON v.owner_id = o.owner_id
    WHERE o.total_points >= 12
      AND p.permit_status = N'有效';

    PRINT N'触发器：车主积分已自动更新';
END;
GO

-- ============================================================
-- 触发器 2：通行证到期自动失效
-- 用途：当查询通行证时，自动将过期的通行证状态更新为"过期"
-- 注意：这是一个 INSTEAD OF 触发器示例，实际使用时可改为定时任务
-- ============================================================
IF OBJECT_ID('tr_CheckPermitExpiry', 'TR') IS NOT NULL
    DROP TRIGGER tr_CheckPermitExpiry;
GO

CREATE TRIGGER tr_CheckPermitExpiry
ON Permit
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 将已过期的通行证状态更新为"过期"
    UPDATE Permit
    SET permit_status = N'过期'
    WHERE end_date < GETDATE()
      AND permit_status = N'有效';

    PRINT N'触发器：已检查通行证有效期';
END;
GO

-- ============================================================
-- 触发器 3：禁止删除有未处理处罚的车主
-- 用途：当尝试删除车主时，检查是否有未处理的处罚记录
-- ============================================================
IF OBJECT_ID('tr_PreventDeleteOwnerWithPenalties', 'TR') IS NOT NULL
    DROP TRIGGER tr_PreventDeleteOwnerWithPenalties;
GO

CREATE TRIGGER tr_PreventDeleteOwnerWithPenalties
ON Owner
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 检查是否有未处理的处罚
    IF EXISTS (
        SELECT 1
        FROM deleted d
        JOIN Vehicle v ON d.owner_id = v.owner_id
        JOIN Violation vi ON v.plate_number = vi.plate_number
        JOIN Penalty p ON vi.violation_id = p.violation_id
        WHERE p.penalty_status = N'待处理'
    )
    BEGIN
        RAISERROR(N'该车主有未处理的处罚记录，无法删除', 16, 1);
        RETURN;
    END

    -- 如果没有未处理的处罚，执行删除（级联删除会自动处理相关记录）
    DELETE FROM Owner WHERE owner_id IN (SELECT owner_id FROM deleted);

    PRINT N'车主删除成功';
END;
GO

-- ============================================================
-- 触发器 4：记录处罚处理日志
-- 用途：当处罚状态更新时，记录处理时间
-- ============================================================
IF OBJECT_ID('tr_LogPenaltyProcess', 'TR') IS NOT NULL
    DROP TRIGGER tr_LogPenaltyProcess;
GO

CREATE TRIGGER tr_LogPenaltyProcess
ON Penalty
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 如果处罚状态从"待处理"变为"已处理"，自动设置处理时间
    UPDATE p
    SET p.process_time = GETDATE()
    FROM Penalty p
    JOIN inserted i ON p.penalty_id = i.penalty_id
    JOIN deleted d ON p.penalty_id = d.penalty_id
    WHERE d.penalty_status = N'待处理'
      AND i.penalty_status = N'已处理'
      AND i.process_time IS NULL;

    PRINT N'触发器：处罚处理时间已记录';
END;
GO

PRINT '===== 触发器创建完成 =====';
PRINT '1. tr_AfterInsertViolation - 违规记录插入后自动更新车主积分';
PRINT '2. tr_CheckPermitExpiry - 通行证到期自动失效';
PRINT '3. tr_PreventDeleteOwnerWithPenalties - 禁止删除有未处理处罚的车主';
PRINT '4. tr_LogPenaltyProcess - 记录处罚处理日志';
GO
