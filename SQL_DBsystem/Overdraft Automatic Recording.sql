IF OBJECT_ID('trg_Account_Overdraft', 'TR') IS NOT NULL
    DROP TRIGGER trg_Account_Overdraft;
GO

CREATE TRIGGER trg_Account_Overdraft
ON Account
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 找出从非负变为负数的账户
    INSERT INTO OverDraftLog(AccountID, OverDraftDate, OverDraftAmount, OverDraftTransactionXML)
    SELECT
        i.AccountID,
        GETDATE() AS OverDraftDate,
        ABS(i.CurrentBalance) AS OverDraftAmount,
        CONVERT(XML,
            '<overdraft account="' + CAST(i.AccountID AS VARCHAR(20)) +
            '" oldBalance="' + CAST(d.CurrentBalance AS VARCHAR(20)) +
            '" newBalance="' + CAST(i.CurrentBalance AS VARCHAR(20)) + '"/>'
        )
    FROM inserted i
    JOIN deleted d ON i.AccountID = d.AccountID
    WHERE d.CurrentBalance >= 0
      AND i.CurrentBalance < 0;
END;
GO


PRINT '================ Demo 3: 透支触发器（trg_Account_Overdraft） ================';

PRINT '--- 0) 查看 AccountID = 6 当前余额 ---';
SELECT AccountID, CurrentBalance
FROM Account
WHERE AccountID = 6;
GO

PRINT '--- 1) 先把 AccountID = 6 的余额设置为 50，方便制造透支 ---';
UPDATE Account
SET CurrentBalance = 50
WHERE AccountID = 6;
GO

PRINT '--- 2) 再通过取款存储过程执行一次超额取款 200（会变成负数） ---';
EXEC sp_Update_cBalance_After_Withdraw
    @AccountID = 6,
    @Withdraw  = 200;
GO

PRINT '--- 3) 取款后再看 AccountID = 6 的余额 ---';
SELECT AccountID, CurrentBalance
FROM Account
WHERE AccountID = 6;
GO

PRINT '--- 4) 查看 OverDraftLog 中最近插入的记录 ---';
SELECT TOP 5
    OverDraftLogID,
    AccountID,
    OverDraftDate,
    OverDraftAmount,
    OverDraftTransactionXML
FROM OverDraftLog
WHERE AccountID = 6
ORDER BY OverDraftLogID DESC;
GO
