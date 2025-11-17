/* =============================
   第二部分：测试 / 演示输出
   ============================= */

-------------------------
-- 1. 视图测试
-------------------------
PRINT '--- Q1: VW_CustomerChecking_ON ---';
SELECT * FROM VW_CustomerChecking_ON;

PRINT '--- Q2: VW_CustomerBalanceOver5000 ---';
SELECT * FROM VW_CustomerBalanceOver5000;

PRINT '--- Q3: VW_CustomerAccountCounts ---';
SELECT * FROM VW_CustomerAccountCounts;

PRINT '--- Q4: VW_Account_UserLogin (AccountID = 1) ---';
SELECT * FROM VW_Account_UserLogin WHERE AccountID = 1;

PRINT '--- Q5: VW_Customer_Overdraft ---';
SELECT * FROM VW_Customer_Overdraft;
GO

-------------------------
-- 2. 存储过程测试
-------------------------

-- Q6: 更新登录名前缀
PRINT '--- Q6: sp_Update_Login 之前的 UserLogins ---';
SELECT * FROM UserLogins;

PRINT '--- 执行 sp_Update_Login ---';
EXEC sp_Update_Login;

PRINT '--- Q6: sp_Update_Login 之后的 UserLogins ---';
SELECT * FROM UserLogins;
GO

-- Q7: 根据 AccountID 查客户全名
PRINT '--- Q7: sp_Customer_Details 对 AccountID = 2 ---';
EXEC sp_Customer_Details @AccountID = 2;
GO

-- 给 Q8 / Q12 加一条“当前时间”的错误日志，方便看得到结果
INSERT INTO LoginErrorLog(ErrorTime, UserLoginID, ErrorMessage, ErrorDetailsXML)
VALUES (GETDATE(), 1, 'Test error in last 24h', '<error code="TEST24"/>');
GO

-- Q8: 最近 24 小时错误日志
PRINT '--- Q8: sp_Errors_24 ---';
EXEC sp_Errors_24;
GO

-- Q9: 存款
PRINT '--- Q9: AccountID = 3 存款前余额 ---';
SELECT AccountID, CurrentBalance FROM Account WHERE AccountID = 3;

PRINT '--- 执行 sp_Update_cBalance_After_Deposit (3, 300) ---';
EXEC sp_Update_cBalance_After_Deposit @AccountID = 3, @Deposit = 300;

PRINT '--- Q9: 存款后余额 ---';
SELECT AccountID, CurrentBalance FROM Account WHERE AccountID = 3;
GO

-- Q10: 取款
PRINT '--- Q10: AccountID = 3 取款前余额 ---';
SELECT AccountID, CurrentBalance FROM Account WHERE AccountID = 3;

PRINT '--- 执行 sp_Update_cBalance_After_Withdraw (3, 200) ---';
EXEC sp_Update_cBalance_After_Withdraw @AccountID = 3, @Withdraw = 200;

PRINT '--- Q10: 取款后余额 ---';
SELECT AccountID, CurrentBalance FROM Account WHERE AccountID = 3;
GO

-- Q11: 删除某个登录的密保答案
PRINT '--- Q11: 删除前 UserSecurityAnswers ---';
SELECT * FROM UserSecurityAnswers WHERE UserLoginID = 5;

PRINT '--- 执行 sp_Delete_Question (5) ---';
EXEC sp_Delete_Question @UserLoginID = 5;

PRINT '--- Q11: 删除后 UserSecurityAnswers ---';
SELECT * FROM UserSecurityAnswers WHERE UserLoginID = 5;
GO

-- Q12: 删除最近 1 小时错误日志
PRINT '--- Q12: 删除前 LoginErrorLog (最近 1 小时内) ---';
SELECT * FROM LoginErrorLog
WHERE ErrorTime BETWEEN DATEADD(HOUR, -1, GETDATE()) AND GETDATE();

PRINT '--- 执行 sp_Delete_Errors ---';
EXEC sp_Delete_Errors;

PRINT '--- Q12: 删除后 LoginErrorLog (最近 1 小时内) ---';
SELECT * FROM LoginErrorLog
WHERE ErrorTime BETWEEN DATEADD(HOUR, -1, GETDATE()) AND GETDATE();
GO

-- Q13: 删除 Customer.SSN 列
PRINT '--- Q13: Customer 表列信息（删除前） ---';
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Customer';

PRINT '--- 执行 sp_Remove_Column ---';
EXEC sp_Remove_Column;

PRINT '--- Q13: Customer 表列信息（删除后） ---';
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Customer';
GO
