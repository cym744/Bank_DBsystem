IF OBJECT_ID('VW_CustomerChecking_ON', 'V') IS NOT NULL
    DROP VIEW VW_CustomerChecking_ON;
GO

CREATE VIEW VW_CustomerChecking_ON
AS
SELECT DISTINCT
    C.CustomerID,
    C.CustomerFirstName,
    C.CustomerMiddleInitial,
    C.CustomerLastName,
    C.City,
    C.State,
    AT.AccountTypeDescription
FROM Customer C
JOIN CustomerAccount CA ON C.CustomerID = CA.CustomerID
JOIN Account A          ON CA.AccountID = A.AccountID
JOIN AccountType AT     ON A.AccountTypeID = AT.AccountTypeID
WHERE AT.AccountTypeCode = 'CHK'
  AND C.State = 'ON';
GO

IF OBJECT_ID('VW_CustomerBalanceOver5000', 'V') IS NOT NULL
    DROP VIEW VW_CustomerBalanceOver5000;
GO

CREATE VIEW VW_CustomerBalanceOver5000
AS
SELECT
    C.CustomerID,
    C.CustomerFirstName,
    SUM(A.CurrentBalance) AS TotalBalance_NoInterest,
    SUM(
        CASE 
            WHEN S.InterestRatesValue IS NOT NULL 
                THEN A.CurrentBalance * (1 + S.InterestRatesValue / 100.0)
            ELSE A.CurrentBalance
        END
    ) AS TotalBalance_WithInterest
FROM Customer C
JOIN CustomerAccount CA ON C.CustomerID = CA.CustomerID
JOIN Account A          ON CA.AccountID = A.AccountID
LEFT JOIN SavingsInterestRates S ON A.InterestSavingRatesID = S.InterestSavingRatesID
GROUP BY C.CustomerID, C.CustomerFirstName
HAVING SUM(
        CASE 
            WHEN S.InterestRatesValue IS NOT NULL 
                THEN A.CurrentBalance * (1 + S.InterestRatesValue / 100.0)
            ELSE A.CurrentBalance
        END
    ) > 5000;
GO

IF OBJECT_ID('VW_CustomerAccountCounts', 'V') IS NOT NULL
    DROP VIEW VW_CustomerAccountCounts;
GO

CREATE VIEW VW_CustomerAccountCounts
AS
SELECT
    C.CustomerID,
    C.CustomerFirstName,
    SUM(CASE WHEN AT.AccountTypeCode = 'SAV' THEN 1 ELSE 0 END) AS SavingsCount,
    SUM(CASE WHEN AT.AccountTypeCode = 'CHK' THEN 1 ELSE 0 END) AS CheckingCount,
    COUNT(*) AS TotalAccounts
FROM Customer C
JOIN CustomerAccount CA ON C.CustomerID = CA.CustomerID
JOIN Account A          ON CA.AccountID = A.AccountID
JOIN AccountType AT     ON A.AccountTypeID = AT.AccountTypeID
GROUP BY C.CustomerID, C.CustomerFirstName;
GO


IF OBJECT_ID('VW_Account_UserLogin', 'V') IS NOT NULL
    DROP VIEW VW_Account_UserLogin;
GO

CREATE VIEW VW_Account_UserLogin
AS
SELECT
    LA.AccountID,
    UL.UserLogin,
    UL.UserPassword
FROM LoginAccount LA
JOIN UserLogins UL ON LA.UserLoginID = UL.UserLoginID;
GO

-- 使用示例：
-- SELECT * FROM VW_Account_UserLogin WHERE AccountID = 1;

IF OBJECT_ID('VW_Customer_Overdraft', 'V') IS NOT NULL
    DROP VIEW VW_Customer_Overdraft;
GO

CREATE VIEW VW_Customer_Overdraft
AS
SELECT
    C.CustomerID,
    C.CustomerFirstName,
    C.CustomerLastName,
    O.AccountID,
    O.OverDraftDate,
    O.OverDraftAmount
FROM OverDraftLog O
JOIN CustomerAccount CA ON O.AccountID = CA.AccountID
JOIN Customer C         ON CA.CustomerID = C.CustomerID;
GO

IF OBJECT_ID('sp_Update_Login', 'P') IS NOT NULL
    DROP PROCEDURE sp_Update_Login;
GO

CREATE PROCEDURE sp_Update_Login
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE UserLogins
    SET UserLogin = 'User_' + UserLogin
    WHERE UserLogin NOT LIKE 'User\_%' ESCAPE '\';
END;
GO

-- EXEC sp_Update_Login;

IF OBJECT_ID('sp_Customer_Details', 'P') IS NOT NULL
    DROP PROCEDURE sp_Customer_Details;
GO

CREATE PROCEDURE sp_Customer_Details
    @AccountID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        C.CustomerID,
        Customer_Full_Name = 
            LTRIM(RTRIM(
                C.CustomerFirstName + ' ' +
                ISNULL(C.CustomerMiddleInitial + ' ', '') +
                C.CustomerLastName
            ))
    FROM Customer C
    JOIN CustomerAccount CA ON C.CustomerID = CA.CustomerID
    WHERE CA.AccountID = @AccountID;
END;
GO

-- 示例：
-- EXEC sp_Customer_Details @AccountID = 2;

IF OBJECT_ID('sp_Errors_24', 'P') IS NOT NULL
    DROP PROCEDURE sp_Errors_24;
GO

CREATE PROCEDURE sp_Errors_24
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM LoginErrorLog
    WHERE ErrorTime BETWEEN DATEADD(HOUR, -24, GETDATE()) AND GETDATE();
END;
GO

-- EXEC sp_Errors_24;


IF OBJECT_ID('sp_Update_cBalance_After_Deposit', 'P') IS NOT NULL
    DROP PROCEDURE sp_Update_cBalance_After_Deposit;
GO

CREATE PROCEDURE sp_Update_cBalance_After_Deposit
    @AccountID INT,
    @Deposit   MONEY
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Account
    SET CurrentBalance = CurrentBalance + @Deposit
    WHERE AccountID = @AccountID;
END;
GO

-- EXEC sp_Update_cBalance_After_Deposit @AccountID = 3, @Deposit = 300;

IF OBJECT_ID('sp_Update_cBalance_After_Withdraw', 'P') IS NOT NULL
    DROP PROCEDURE sp_Update_cBalance_After_Withdraw;
GO

CREATE PROCEDURE sp_Update_cBalance_After_Withdraw
    @AccountID INT,
    @Withdraw  MONEY
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM Account
        WHERE AccountID = @AccountID
          AND CurrentBalance >= @Withdraw
    )
    BEGIN
        UPDATE Account
        SET CurrentBalance = CurrentBalance - @Withdraw
        WHERE AccountID = @AccountID;
    END
    ELSE
    BEGIN
        RAISERROR('Insufficient balance for withdrawal.', 16, 1);
    END
END;
GO

-- EXEC sp_Update_cBalance_After_Withdraw @AccountID = 3, @Withdraw = 300;

IF OBJECT_ID('sp_Delete_Question', 'P') IS NOT NULL
    DROP PROCEDURE sp_Delete_Question;
GO

CREATE PROCEDURE sp_Delete_Question
    @UserLoginID SMALLINT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE UA
    FROM UserSecurityAnswers UA
    WHERE UA.UserLoginID = @UserLoginID;
END;
GO

-- EXEC sp_Delete_Question @UserLoginID = 5;

IF OBJECT_ID('sp_Delete_Errors', 'P') IS NOT NULL
    DROP PROCEDURE sp_Delete_Errors;
GO

CREATE PROCEDURE sp_Delete_Errors
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM LoginErrorLog
    WHERE ErrorTime BETWEEN DATEADD(HOUR, -1, GETDATE()) AND GETDATE();
END;
GO

-- EXEC sp_Delete_Errors;

IF OBJECT_ID('sp_Remove_Column', 'P') IS NOT NULL
    DROP PROCEDURE sp_Remove_Column;
GO

CREATE PROCEDURE sp_Remove_Column
AS
BEGIN
    SET NOCOUNT ON;

    IF COL_LENGTH('Customer', 'SSN') IS NOT NULL
    BEGIN
        ALTER TABLE Customer
        DROP COLUMN SSN;
    END
END;
GO

-- EXEC sp_Remove_Column;

