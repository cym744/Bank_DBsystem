

IF OBJECT_ID('sp_ApplyMonthlyInterest', 'P') IS NOT NULL
    DROP PROCEDURE sp_ApplyMonthlyInterest;
GO

CREATE PROCEDURE sp_ApplyMonthlyInterest
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @AsOfDate IS NULL
        SET @AsOfDate = CAST(GETDATE() AS DATE);

    DECLARE @InterestTypeID TINYINT;

    -- 可选择用专门类型，如 'Interest'，这里简单用 'Deposit'
    SELECT @InterestTypeID = TransactionTypeID
    FROM TransactionType
    WHERE TransactionTypeName = 'Deposit';

    IF @InterestTypeID IS NULL
    BEGIN
        RAISERROR('TransactionType ''Deposit'' not defined.',16,1);
        RETURN;
    END;

    -- 暂存要计算利息的账户和利息金额
    IF OBJECT_ID('tempdb..#InterestCalc') IS NOT NULL
        DROP TABLE #InterestCalc;

    CREATE TABLE #InterestCalc(
        AccountID INT PRIMARY KEY,
        Interest  MONEY NOT NULL
    );

    INSERT INTO #InterestCalc(AccountID, Interest)
    SELECT
        A.AccountID,
        CAST( A.CurrentBalance * (S.InterestRatesValue / 100.0 / 12.0) AS MONEY ) AS InterestAmount
    FROM Account A
    JOIN SavingsInterestRates S ON A.InterestSavingRatesID = S.InterestSavingRatesID
    WHERE A.AccountStatusTypeID = 1  -- 假设1=Active
      AND A.CurrentBalance > 0;

    BEGIN TRY
        BEGIN TRAN;

        -- 更新账户余额
        UPDATE A
        SET A.CurrentBalance = A.CurrentBalance + I.Interest
        FROM Account A
        JOIN #InterestCalc I ON A.AccountID = I.AccountID;

        -- 为每个账户插入一条利息交易记录
        INSERT INTO TransactionLog
        (TransactionDate, TransactionTypeID, TransactionAmount, NewBalance,
         AccountID, CustomerID, EmployeeID, UserLoginID)
        SELECT
            DATEADD(SECOND, 1, CAST(@AsOfDate AS DATETIME)) AS TransactionDate,
            @InterestTypeID,
            I.Interest,
            A.CurrentBalance,   -- 已经更新后的新余额
            A.AccountID,
            CA.CustomerID,
            1 AS EmployeeID,    -- 系统任务，可用一个虚拟柜员
            C.UserLoginID
        FROM #InterestCalc I
        JOIN Account A        ON I.AccountID = A.AccountID
        JOIN CustomerAccount CA ON A.AccountID = CA.AccountID
        JOIN Customer C          ON CA.CustomerID = C.CustomerID;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @Msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Msg,16,1);
    END CATCH
END;
GO

-- 示例：
-- EXEC sp_ApplyMonthlyInterest;   -- 对全体活跃有利率的账户结一次息



PRINT '================ Demo 2: 月度利息结算（sp_ApplyMonthlyInterest） ================';
PRINT '--- 1) 结息前：查看有利率的活跃账户余额 ---';
SELECT 
    A.AccountID,
    A.CurrentBalance,
    S.InterestRatesValue,
    S.InterestRatesDescription
FROM Account A
JOIN SavingsInterestRates S ON A.InterestSavingRatesID = S.InterestSavingRatesID
WHERE A.AccountStatusTypeID = 1;   -- 假设1=Active
GO

PRINT '--- 2) 执行月度利息结算（AsOfDate = 2025-01-01） ---';
EXEC sp_ApplyMonthlyInterest @AsOfDate = '2025-01-01';
GO

PRINT '--- 3) 结息后：再看这些账户的余额 ---';
SELECT 
    A.AccountID,
    A.CurrentBalance,
    S.InterestRatesValue,
    S.InterestRatesDescription
FROM Account A
JOIN SavingsInterestRates S ON A.InterestSavingRatesID = S.InterestSavingRatesID
WHERE A.AccountStatusTypeID = 1;
GO

PRINT '--- 4) 查看刚刚产生的利息交易记录（TransactionLog） ---';
SELECT
    TransactionID,
    TransactionDate,
    TransactionTypeID,
    TransactionAmount,
    NewBalance,
    AccountID,
    CustomerID
FROM TransactionLog
WHERE CAST(TransactionDate AS DATE) = '2025-01-01'
  AND TransactionAmount > 0   -- 利息一般是正数
ORDER BY TransactionID;
GO