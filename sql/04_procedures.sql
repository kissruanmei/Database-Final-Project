-- ============================================================
-- 校园机动车综合管理平台 - 存储过程
-- ============================================================

USE CampusVehicleDB;
GO

-- ============================================================
-- 存储过程 1：录入违规记录
-- 用途：管理员录入新的违规记录，同时自动更新车主积分
-- 参数：车牌号、违规类型、违规时间、违规地点、描述、扣分、管理员ID
-- ============================================================
IF OBJECT_ID('sp_AddViolation', 'P') IS NOT NULL
    DROP PROCEDURE sp_AddViolation;
GO

CREATE PROCEDURE sp_AddViolation
    @plate_number       VARCHAR(10),
    @violation_type     VARCHAR(50),
    @violation_time     DATETIME,
    @violation_location VARCHAR(100),
    @violation_desc     TEXT = NULL,
    @points_deducted    INT,
    @admin_id           INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 检查车辆是否存在
    IF NOT EXISTS (SELECT 1 FROM Vehicle WHERE plate_number = @plate_number)
    BEGIN
        RAISERROR(N'车牌号 %s 不存在', 16, 1, @plate_number);
        RETURN;
    END

    -- 检查管理员是否存在
    IF NOT EXISTS (SELECT 1 FROM Admin WHERE admin_id = @admin_id)
    BEGIN
        RAISERROR(N'管理员ID %d 不存在', 16, 1, @admin_id);
        RETURN;
    END

    -- 检查扣分是否有效
    IF @points_deducted <= 0
    BEGIN
        RAISERROR(N'扣分必须大于0', 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;

    BEGIN TRY
        -- 插入违规记录
        INSERT INTO Violation (plate_number, violation_type, violation_time,
                              violation_location, violation_desc, points_deducted, admin_id)
        VALUES (@plate_number, @violation_type, @violation_time,
                @violation_location, @violation_desc, @points_deducted, @admin_id);

        -- 更新车主累计积分
        UPDATE Owner
        SET total_points = total_points + @points_deducted
        WHERE owner_id = (SELECT owner_id FROM Vehicle WHERE plate_number = @plate_number);

        COMMIT TRANSACTION;

        -- 返回新插入的违规ID
        SELECT SCOPE_IDENTITY() AS 新违规编号;

        PRINT N'违规记录录入成功';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 存储过程 2：处理处罚
-- 用途：管理员处理处罚记录，更新状态和处理时间
-- 参数：处罚ID、管理员ID
-- ============================================================
IF OBJECT_ID('sp_ProcessPenalty', 'P') IS NOT NULL
    DROP PROCEDURE sp_ProcessPenalty;
GO

CREATE PROCEDURE sp_ProcessPenalty
    @penalty_id     INT,
    @admin_id       INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 检查处罚记录是否存在
    IF NOT EXISTS (SELECT 1 FROM Penalty WHERE penalty_id = @penalty_id)
    BEGIN
        RAISERROR(N'处罚记录ID %d 不存在', 16, 1, @penalty_id);
        RETURN;
    END

    -- 检查处罚状态
    DECLARE @current_status VARCHAR(10);
    SELECT @current_status = penalty_status FROM Penalty WHERE penalty_id = @penalty_id;

    IF @current_status = N'已处理'
    BEGIN
        RAISERROR(N'该处罚已处理，不可重复处理', 16, 1);
        RETURN;
    END

    IF @current_status = N'申诉通过'
    BEGIN
        RAISERROR(N'该处罚已申诉通过，无需处理', 16, 1);
        RETURN;
    END

    -- 更新处罚状态
    UPDATE Penalty
    SET penalty_status = N'已处理',
        process_time = GETDATE(),
        admin_id = @admin_id
    WHERE penalty_id = @penalty_id;

    PRINT N'处罚处理成功';
END;
GO

-- ============================================================
-- 存储过程 3：查询车主违规历史
-- 用途：根据车主ID查询其名下所有车辆的违规记录
-- 参数：车主ID
-- ============================================================
IF OBJECT_ID('sp_GetOwnerViolations', 'P') IS NOT NULL
    DROP PROCEDURE sp_GetOwnerViolations;
GO

CREATE PROCEDURE sp_GetOwnerViolations
    @owner_id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 检查车主是否存在
    IF NOT EXISTS (SELECT 1 FROM Owner WHERE owner_id = @owner_id)
    BEGIN
        RAISERROR(N'车主ID %d 不存在', 16, 1, @owner_id);
        RETURN;
    END

    -- 查询车主基本信息
    SELECT
        owner_id AS 车主编号,
        owner_name AS 车主姓名,
        owner_type AS 车主类型,
        department AS 所属部门,
        total_points AS 累计扣分
    FROM Owner
    WHERE owner_id = @owner_id;

    -- 查询违规记录
    SELECT
        v.plate_number AS 车牌号,
        vi.violation_type AS 违规类型,
        vi.violation_time AS 违规时间,
        vi.violation_location AS 违规地点,
        vi.points_deducted AS 扣分,
        a.admin_name AS 录入管理员
    FROM Vehicle v
    JOIN Violation vi ON v.plate_number = vi.plate_number
    JOIN Admin a ON vi.admin_id = a.admin_id
    WHERE v.owner_id = @owner_id
    ORDER BY vi.violation_time DESC;
END;
GO

-- ============================================================
-- 存储过程 4：统计违规数量
-- 用途：按时间段统计各类型违规的数量
-- 参数：开始日期、结束日期
-- ============================================================
IF OBJECT_ID('sp_StatViolationsByPeriod', 'P') IS NOT NULL
    DROP PROCEDURE sp_StatViolationsByPeriod;
GO

CREATE PROCEDURE sp_StatViolationsByPeriod
    @start_date DATE,
    @end_date   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 检查日期有效性
    IF @end_date < @start_date
    BEGIN
        RAISERROR(N'结束日期不能早于开始日期', 16, 1);
        RETURN;
    END

    -- 统计各类型违规数量
    SELECT
        violation_type AS 违规类型,
        COUNT(*) AS 违规次数,
        SUM(points_deducted) AS 总扣分
    FROM Violation
    WHERE violation_time >= @start_date
      AND violation_time < DATEADD(DAY, 1, @end_date)
    GROUP BY violation_type
    ORDER BY 违规次数 DESC;

    -- 统计每日违规趋势
    SELECT
        CAST(violation_time AS DATE) AS 日期,
        COUNT(*) AS 违规次数
    FROM Violation
    WHERE violation_time >= @start_date
      AND violation_time < DATEADD(DAY, 1, @end_date)
    GROUP BY CAST(violation_time AS DATE)
    ORDER BY 日期;
END;
GO

-- ============================================================
-- 存储过程 5：通行证续期
-- 用途：为指定通行证续期，更新有效期
-- 参数：通行证ID、新到期日期、管理员ID
-- ============================================================
IF OBJECT_ID('sp_RenewPermit', 'P') IS NOT NULL
    DROP PROCEDURE sp_RenewPermit;
GO

CREATE PROCEDURE sp_RenewPermit
    @permit_id      INT,
    @new_end_date   DATE,
    @admin_id       INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 检查通行证是否存在
    IF NOT EXISTS (SELECT 1 FROM Permit WHERE permit_id = @permit_id)
    BEGIN
        RAISERROR(N'通行证ID %d 不存在', 16, 1, @permit_id);
        RETURN;
    END

    -- 检查通行证状态
    DECLARE @current_status VARCHAR(10);
    SELECT @current_status = permit_status FROM Permit WHERE permit_id = @permit_id;

    IF @current_status = N'注销'
    BEGIN
        RAISERROR(N'该通行证已注销，无法续期', 16, 1);
        RETURN;
    END

    -- 检查新日期是否有效
    DECLARE @current_start DATE;
    SELECT @current_start = start_date FROM Permit WHERE permit_id = @permit_id;

    IF @new_end_date <= @current_start
    BEGIN
        RAISERROR(N'新到期日期必须晚于生效日期', 16, 1);
        RETURN;
    END

    -- 更新通行证
    UPDATE Permit
    SET end_date = @new_end_date,
        permit_status = N'有效',
        admin_id = @admin_id
    WHERE permit_id = @permit_id;

    PRINT N'通行证续期成功';
END;
GO

-- ============================================================
-- 存储过程 6：注册新车辆
-- 用途：车主注册新车辆并申请通行证
-- 参数：车主ID、车牌号、车辆类型、颜色、通行证类型、管理员ID
-- ============================================================
IF OBJECT_ID('sp_RegisterVehicle', 'P') IS NOT NULL
    DROP PROCEDURE sp_RegisterVehicle;
GO

CREATE PROCEDURE sp_RegisterVehicle
    @owner_id       INT,
    @plate_number   VARCHAR(10),
    @vehicle_type   VARCHAR(20),
    @vehicle_color  VARCHAR(10),
    @permit_type    VARCHAR(20),
    @admin_id       INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 检查车主是否存在
    IF NOT EXISTS (SELECT 1 FROM Owner WHERE owner_id = @owner_id)
    BEGIN
        RAISERROR(N'车主ID %d 不存在', 16, 1, @owner_id);
        RETURN;
    END

    -- 检查车牌号是否已存在
    IF EXISTS (SELECT 1 FROM Vehicle WHERE plate_number = @plate_number)
    BEGIN
        RAISERROR(N'车牌号 %s 已存在', 16, 1, @plate_number);
        RETURN;
    END

    -- 检查车主积分是否超标
    DECLARE @current_points INT;
    SELECT @current_points = total_points FROM Owner WHERE owner_id = @owner_id;

    IF @current_points >= 12
    BEGIN
        RAISERROR(N'车主累计扣分已达12分，无法注册新车辆', 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;

    BEGIN TRY
        -- 插入车辆信息
        INSERT INTO Vehicle (plate_number, vehicle_type, vehicle_color, owner_id)
        VALUES (@plate_number, @vehicle_type, @vehicle_color, @owner_id);

        -- 创建通行证
        INSERT INTO Permit (plate_number, permit_type, start_date, end_date, permit_status, admin_id)
        VALUES (@plate_number, @permit_type, GETDATE(), DATEADD(YEAR, 1, GETDATE()), N'有效', @admin_id);

        COMMIT TRANSACTION;

        PRINT N'车辆注册成功，通行证已发放';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT '===== 存储过程创建完成 =====';
PRINT '1. sp_AddViolation - 录入违规记录（自动更新车主积分）';
PRINT '2. sp_ProcessPenalty - 处理处罚';
PRINT '3. sp_GetOwnerViolations - 查询车主违规历史';
PRINT '4. sp_StatViolationsByPeriod - 按时间段统计违规数量';
PRINT '5. sp_RenewPermit - 通行证续期';
PRINT '6. sp_RegisterVehicle - 注册新车辆';
GO
