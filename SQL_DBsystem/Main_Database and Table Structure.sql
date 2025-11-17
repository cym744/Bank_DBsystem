IF OBJECT_ID('sp_TransferFunds', 'P') IS NOT NULL
    DROP PROCEDURE sp_TransferFunds;
GO

CREATE PROCEDURE sp_TransferFunds
    @SourceAccountID INT,
    @TargetAccountID INT,
    @Amount          MONEY,
    @CustomerID      INT,        -- 发起者（简化处理）
    @EmployeeID      INT = NULL, -- 柜员操作可填
    @UserLoginID     SMALLINT    -- 登录账号
AS
BEGIN
    SET NOCOUNT ON;

    IF @Amount <= 0
    BEGIN
        RAISERROR('Amount must be greater than 0.',16,1);
        RETURN;
    END;

    DECLARE @SourceBalance MONEY;
    DECLARE @SourceStatusID TINYINT;
    DECLARE @TargetStatusID TINYINT;

    SELECT @SourceBalance   = CurrentBalance,
           @SourceStatusID  = AccountStatusTypeID
    FROM Account WHERE AccountID = @SourceAccountID;

    SELECT @TargetStatusID  = AccountStatusTypeID
    FROM Account WHERE AccountID = @TargetAccountID;

    IF @SourceBalance IS NULL
    BEGIN
        RAISERROR('Source account does not exist.',16,1);
        RETURN;
    END;

    IF @TargetStatusID IS NULL
    BEGIN
        RAISERROR('Target account does not exist.',16,1);
        RETURN;
    END;

    -- 假定 1 = Active
    IF @SourceStatusID <> 1 OR @TargetStatusID <> 1
    BEGIN
        RAISERROR('One of the accounts is not active.',16,1);
        RETURN;
    END;

    IF @SourceBalance < @Amount
    BEGIN
        RAISERROR('Insufficient funds in source account.',16,1);
        RETURN;
    END;

    DECLARE @TransferTypeID TINYINT;

    SELECT @TransferTypeID = TransactionTypeID
    FROM TransactionType
    WHERE TransactionTypeName = 'Transfer';

    IF @TransferTypeID IS NULL
    BEGIN
        RAISERROR('TransactionType ''Transfer'' not defined.',16,1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        -- 源账户扣钱
        UPDATE Account
        SET CurrentBalance = CurrentBalance - @Amount
        WHERE AccountID = @SourceAccountID;

        DECLARE @NewSourceBalance MONEY;
        SELECT @NewSourceBalance = CurrentBalance
        FROM Account WHERE AccountID = @SourceAccountID;

        INSERT INTO TransactionLog
        (TransactionDate, TransactionTypeID, TransactionAmount, NewBalance,
         AccountID, CustomerID, EmployeeID, UserLoginID)
        VALUES
        (GETDATE(), @TransferTypeID, -@Amount, @NewSourceBalance,
         @SourceAccountID, @CustomerID, ISNULL(@EmployeeID,1), @UserLoginID);

        -- 目标账户加钱
        UPDATE Account
        SET CurrentBalance = CurrentBalance + @Amount
        WHERE AccountID = @TargetAccountID;

        DECLARE @NewTargetBalance MONEY;
        SELECT @NewTargetBalance = CurrentBalance
        FROM Account WHERE AccountID = @TargetAccountID;

        INSERT INTO TransactionLog
        (TransactionDate, TransactionTypeID, TransactionAmount, NewBalance,
         AccountID, CustomerID, EmployeeID, UserLoginID)
        VALUES
        (GETDATE(), @TransferTypeID, @Amount, @NewTargetBalance,
         @TargetAccountID, @CustomerID, ISNULL(@EmployeeID,1), @UserLoginID);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        DECLARE @Msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Msg, 16, 1);
    END CATCH
END;
GO

-- 示例：
-- EXEC sp_TransferFunds @SourceAccountID=1, @TargetAccountID=2, @Amount=1000,
--                       @CustomerID=1, @EmployeeID=NULL, @UserLoginID=1;


PRINT '================ Demo 1: 账户转账（sp_TransferFunds） ================';
PRINT '--- 1) 转账前 Account 余额 ---';
SELECT AccountID, CurrentBalance
FROM Account
WHERE AccountID IN (1,2);
GO

PRINT '--- 2) 执行转账：从 1 转给 2，金额 1000 ---';
EXEC sp_TransferFunds
    @SourceAccountID = 1,
    @TargetAccountID = 2,
    @Amount          = 1000,
    @CustomerID      = 1,   -- 假设 CustomerID=1 是账户1的持有人
    @EmployeeID      = NULL,
    @UserLoginID     = 1;
GO

PRINT '--- 3) 转账后 Account 余额 ---';
SELECT AccountID, CurrentBalance
FROM Account
WHERE AccountID IN (1,2);
GO

PRINT '--- 4) 查看刚刚产生的转账交易流水（TransactionLog，按最新时间排序） ---';
SELECT TOP 10
    TransactionID,
    TransactionDate,
    TransactionTypeID,
    TransactionAmount,
    NewBalance,
    AccountID,
    CustomerID,
    EmployeeID,
    UserLoginID
FROM TransactionLog
WHERE AccountID IN (1,2)
ORDER BY TransactionID DESC;
GO