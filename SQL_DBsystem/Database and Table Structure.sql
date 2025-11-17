-- Q1. 创建数据库
CREATE DATABASE dbBankGM;
GO

USE dbBankGM;
GO

/* =============================
   Q2 & Q3：建表 + 主外键约束
   ============================= */

------------------------
-- 1. 用户与安全问题相关
------------------------
CREATE TABLE UserLogins(
    UserLoginID      SMALLINT      IDENTITY(1,1) PRIMARY KEY,
    UserLogin        VARCHAR(50)   NOT NULL UNIQUE,
    UserPassword     VARCHAR(128)  NOT NULL  -- 预留更长长度，方便日后加密
);
GO

CREATE TABLE UserSecurityQuestions(
    UserSecurityQuestionID  TINYINT      IDENTITY(1,1) PRIMARY KEY,
    QuestionText            VARCHAR(100) NOT NULL
);
GO

-- 标准做法：答案表有自己的主键，UserLoginID 只是外键，不再用 IDENTITY+FK 冲突写法
CREATE TABLE UserSecurityAnswers(
    UserSecurityAnswerID    INT         IDENTITY(1,1) PRIMARY KEY,
    UserLoginID             SMALLINT    NOT NULL,
    UserSecurityQuestionID  TINYINT     NOT NULL,
    AnswerText              VARCHAR(50) NOT NULL,
    CONSTRAINT fk_USA_UserLogin
        FOREIGN KEY(UserLoginID) REFERENCES UserLogins(UserLoginID),
    CONSTRAINT fk_USA_Question
        FOREIGN KEY(UserSecurityQuestionID) REFERENCES UserSecurityQuestions(UserSecurityQuestionID),
    -- 一个用户对同一问题只能有一条答案
    CONSTRAINT uq_USA_User_Question UNIQUE(UserLoginID, UserSecurityQuestionID)
);
GO

------------------------
-- 2. 账户类别、利率、状态
------------------------
CREATE TABLE AccountType(
    AccountTypeID          TINYINT      IDENTITY(1,1) PRIMARY KEY,
    AccountTypeCode        VARCHAR(10)  NOT NULL UNIQUE, -- 如 SAV, CHK
    AccountTypeDescription VARCHAR(30)  NOT NULL
);
GO

CREATE TABLE SavingsInterestRates(
    InterestSavingRatesID  TINYINT      IDENTITY(1,1) PRIMARY KEY,
    InterestRatesValue     NUMERIC(5,2) NOT NULL CHECK (InterestRatesValue >= 0),  -- 例如 0.50 表示 0.5%
    InterestRatesDescription VARCHAR(30) NULL
);
GO

CREATE TABLE AccountStatusType(
    AccountStatusTypeID          TINYINT      IDENTITY(1,1) PRIMARY KEY,
    AccountStatusTypeDescription VARCHAR(30)  NOT NULL
);
GO

------------------------
-- 3. 错误类型、员工、交易类型
------------------------
CREATE TABLE FailedTransactionErrorType(
    FailedTransactionErrorTypeID TINYINT      IDENTITY(1,1) PRIMARY KEY,
    FailedTransactionErrorTypeDescription VARCHAR(50) NOT NULL
);
GO

CREATE TABLE Employee(
    EmployeeID          INT          IDENTITY(1,1) PRIMARY KEY,
    EmployeeFirstName   VARCHAR(25)  NOT NULL,
    EmployeeMiddleInitial CHAR(1)    NULL,
    EmployeeLastName    VARCHAR(25)  NOT NULL,
    EmployeeIsManager   BIT          NOT NULL DEFAULT(0)
);
GO

CREATE TABLE TransactionType(
    TransactionTypeID        TINYINT      IDENTITY(1,1) PRIMARY KEY,
    TransactionTypeName      VARCHAR(20)  NOT NULL,
    TransactionTypeDescription VARCHAR(100) NULL,
    TransactionFeeAmount     SMALLMONEY   NOT NULL DEFAULT(0)
);
GO

------------------------
-- 4. 账户、客户及关联
------------------------
CREATE TABLE Account(
    AccountID            INT        IDENTITY(1,1) PRIMARY KEY,
    CurrentBalance       MONEY      NOT NULL DEFAULT(0),
    AccountTypeID        TINYINT    NOT NULL,
    AccountStatusTypeID  TINYINT    NOT NULL,
    InterestSavingRatesID TINYINT   NULL,  -- 有的账户可能无利率（如支票账户）
    CONSTRAINT fk_Acct_Type
        FOREIGN KEY(AccountTypeID) REFERENCES AccountType(AccountTypeID),
    CONSTRAINT fk_Acct_Status
        FOREIGN KEY(AccountStatusTypeID) REFERENCES AccountStatusType(AccountStatusTypeID),
    CONSTRAINT fk_Acct_Rate
        FOREIGN KEY(InterestSavingRatesID) REFERENCES SavingsInterestRates(InterestSavingRatesID)
);
GO

-- 登录账号与账户之间是多对多，用关联表 + 复合主键
CREATE TABLE LoginAccount(
    UserLoginID  SMALLINT  NOT NULL,
    AccountID    INT       NOT NULL,
    PRIMARY KEY(UserLoginID, AccountID),
    CONSTRAINT fk_LA_UserLogin FOREIGN KEY(UserLoginID) REFERENCES UserLogins(UserLoginID),
    CONSTRAINT fk_LA_Account   FOREIGN KEY(AccountID)   REFERENCES Account(AccountID)
);
GO

CREATE TABLE Customer(
    CustomerID           INT         IDENTITY(1,1) PRIMARY KEY,
    UserLoginID          SMALLINT    NOT NULL UNIQUE,  -- 一个登录对应一个客户
    PrimaryAccountID     INT         NULL,             -- 可选：主账户
    CustomerFirstName    VARCHAR(30) NOT NULL,
    CustomerMiddleInitial CHAR(1)    NULL,
    CustomerLastName     VARCHAR(30) NOT NULL,
    CustomerAddress1     VARCHAR(50) NOT NULL,
    CustomerAddress2     VARCHAR(50) NULL,
    City                 VARCHAR(30) NOT NULL,
    State                CHAR(2)     NOT NULL,
    ZipCode              CHAR(10)    NOT NULL,
    EmailAddress         VARCHAR(60) NOT NULL,
    HomePhone            VARCHAR(15) NULL,
    CellPhone            VARCHAR(15) NULL,
    WorkPhone            VARCHAR(15) NULL,
    SSN                  CHAR(9)     NULL,
    CONSTRAINT fk_Cust_Login FOREIGN KEY(UserLoginID) REFERENCES UserLogins(UserLoginID),
    CONSTRAINT fk_Cust_PrimaryAccount FOREIGN KEY(PrimaryAccountID) REFERENCES Account(AccountID)
);
GO

-- 客户与账户的多对多关系
CREATE TABLE CustomerAccount(
    CustomerID INT NOT NULL,
    AccountID  INT NOT NULL,
    PRIMARY KEY(CustomerID, AccountID),
    CONSTRAINT fk_CA_Customer FOREIGN KEY(CustomerID) REFERENCES Customer(CustomerID),
    CONSTRAINT fk_CA_Account  FOREIGN KEY(AccountID)  REFERENCES Account(AccountID)
);
GO

------------------------
-- 5. 日志与透支记录
------------------------
CREATE TABLE LoginErrorLog(
    ErrorLogID      INT        IDENTITY(1,1) PRIMARY KEY,
    ErrorTime       DATETIME   NOT NULL DEFAULT(GETDATE()),
    UserLoginID     SMALLINT   NULL,
    ErrorMessage    VARCHAR(200) NOT NULL,
    ErrorDetailsXML XML        NULL,
    CONSTRAINT fk_LEL_UserLogin FOREIGN KEY(UserLoginID) REFERENCES UserLogins(UserLoginID)
);
GO

CREATE TABLE FailedTransactionLog(
    FailedTransactionID        INT        IDENTITY(1,1) PRIMARY KEY,
    FailedTransactionErrorTypeID TINYINT  NOT NULL,
    AccountID                  INT        NULL,
    CustomerID                 INT        NULL,
    FailedTransactionErrorTime DATETIME   NOT NULL DEFAULT(GETDATE()),
    FailedTransactionErrorXML  XML        NULL,
    CONSTRAINT fk_FTL_ErrorType FOREIGN KEY(FailedTransactionErrorTypeID) REFERENCES FailedTransactionErrorType(FailedTransactionErrorTypeID),
    CONSTRAINT fk_FTL_Account   FOREIGN KEY(AccountID) REFERENCES Account(AccountID),
    CONSTRAINT fk_FTL_Customer  FOREIGN KEY(CustomerID) REFERENCES Customer(CustomerID)
);
GO

CREATE TABLE OverDraftLog(
    OverDraftLogID         INT       IDENTITY(1,1) PRIMARY KEY,
    AccountID              INT       NOT NULL,
    OverDraftDate          DATETIME  NOT NULL,
    OverDraftAmount        MONEY     NOT NULL,
    OverDraftTransactionXML XML      NULL,
    CONSTRAINT fk_ODL_Account FOREIGN KEY(AccountID) REFERENCES Account(AccountID)
);
GO

CREATE TABLE TransactionLog(
    TransactionID     INT        IDENTITY(1,1) PRIMARY KEY,
    TransactionDate   DATETIME   NOT NULL DEFAULT(GETDATE()),
    TransactionTypeID TINYINT    NOT NULL,
    TransactionAmount MONEY      NOT NULL,
    NewBalance        MONEY      NOT NULL,
    AccountID         INT        NOT NULL,
    CustomerID        INT        NOT NULL,
    EmployeeID        INT        NOT NULL,
    UserLoginID       SMALLINT   NOT NULL,
    CONSTRAINT fk_TL_TransType FOREIGN KEY(TransactionTypeID) REFERENCES TransactionType(TransactionTypeID),
    CONSTRAINT fk_TL_Account   FOREIGN KEY(AccountID) REFERENCES Account(AccountID),
    CONSTRAINT fk_TL_Customer  FOREIGN KEY(CustomerID) REFERENCES Customer(CustomerID),
    CONSTRAINT fk_TL_Employee  FOREIGN KEY(EmployeeID) REFERENCES Employee(EmployeeID),
    CONSTRAINT fk_TL_UserLogin FOREIGN KEY(UserLoginID) REFERENCES UserLogins(UserLoginID)
);
GO

/* =============================
   Q4：插入测试数据（示例）
   ============================= */

-- UserLogins
INSERT INTO UserLogins(UserLogin, UserPassword) VALUES
('alice', 'pwd1'),
('bob',   'pwd2'),
('carol', 'pwd3'),
('david', 'pwd4'),
('eric',  'pwd5'),
('frank',  'pf1'),
('grace',  'pf2'),
('helen',  'pf3'),
('ian',    'pf4'),
('jane',   'pf5'),
('kevin',  'pf6'),
('laura',  'pf7'),
('mario',  'pf8'),
('nina',   'pf9'),
('oliver', 'pf10');
GO

-- UserSecurityQuestions
INSERT INTO UserSecurityQuestions(QuestionText) VALUES
('What is your favourite food?'),
('What is your mother''s maiden name?'),
('What is your first school?'),
('What is your favourite movie?'),
('What is the name of your pet?'),
('What city were you born in?'),
('What is your favourite color?'),
('What was your childhood nickname?'),
('What is your dream job?'),
('What is the name of your first teacher?');
GO

-- UserSecurityAnswers（每个用户一个问题）
INSERT INTO UserSecurityAnswers(UserLoginID, UserSecurityQuestionID, AnswerText) VALUES
(1, 1, 'Pizza'),
(2, 2, 'Smith'),
(3, 3, 'CentralSchool'),
(4, 4, 'Inception'),
(5, 5, 'Tommy'),
(6,  6, 'Toronto'),
(7,  7, 'Blue'),
(8,  8, 'LilHel'),
(9,  9, 'Scientist'),
(10, 10, 'Mrs.White'),
(11, 2, 'AAA'),
(12, 3, 'BBB'),
(13, 4, 'CCC'),
(14, 5, 'DDD'),
(15, 1, 'EEE');
GO

-- AccountType
INSERT INTO AccountType(AccountTypeCode, AccountTypeDescription) VALUES
('SAV', 'Savings'),
('CHK', 'Checking'),
('BUS', 'Business'),
('STU', 'Student'),
('VIP', 'VIP Account'),
('JNT', 'Joint Account'),
('CRD', 'Credit Account');
GO

-- SavingsInterestRates
INSERT INTO SavingsInterestRates(InterestRatesValue, InterestRatesDescription) VALUES
(0.50, 'Low'),
(1.20, 'Standard'),
(2.00, 'Premium'),
(3.00, 'Gold'),
(4.00, 'Platinum'),
(4.50, 'Premium Plus'),
(5.00, 'Diamond'),
(6.00, 'Ultra High Rate');
GO

-- AccountStatusType
INSERT INTO AccountStatusType(AccountStatusTypeDescription) VALUES
('Active'),
('Closed'),
('Dormant'),
('Frozen'),
('Pending'),
('Review'),
('Special Hold');
GO

-- FailedTransactionErrorType
INSERT INTO FailedTransactionErrorType(FailedTransactionErrorTypeDescription) VALUES
('Insufficient funds'),
('Daily withdrawal limit reached'),
('Invalid denomination'),
('Account locked'),
('System error'),
('Card retained'),
('Exceeded PIN attempts'),
('Foreign transaction blocked');
GO

-- Employee
INSERT INTO Employee(EmployeeFirstName, EmployeeMiddleInitial, EmployeeLastName, EmployeeIsManager) VALUES
('John',  'A', 'Brown',  1),
('Lisa',  'B', 'Green',  0),
('Peter', 'C', 'White',  0),
('Nina',  'D', 'Black',  1),
('Mark',  'E', 'Stone',  0),
('Sarah',  'L', 'King',  0),
('Tom',    'Q', 'Park',  1),
('Richard','T', 'Lopez', 0),
('Emily',  'Z', 'Nguyen',1),
('George', 'P', 'Wang',  0);
GO

-- TransactionType
INSERT INTO TransactionType(TransactionTypeName, TransactionTypeDescription, TransactionFeeAmount) VALUES
('Deposit',    'Cash or cheque deposit',      0),
('Withdraw',   'Cash withdrawal',             0.5),
('Transfer',   'Transfer between accounts',   1),
('Payment',    'Bill payment',                1.5),
('Statement',  'Monthly statement printing',  0),
('LoanPay',     'Loan repayment',          2.0),
('CardCharge',  'Credit card charge',      1.0),
('CurrencyEx',  'Currency exchange',       3.0),
('ATMFee',      'ATM service fee',         1.5),
('MobilePay',   'Mobile payment transaction', 0.2);
GO

-- Account（假设 1,3,5 为 Savings；2,4 为 Checking）
INSERT INTO Account(CurrentBalance, AccountTypeID, AccountStatusTypeID, InterestSavingRatesID) VALUES
(15000, 1, 1, 2), -- SAV, Active, 标准利率
( 5000, 2, 1, NULL), -- CHK, Active, 无利率
( 8000, 1, 1, 3),
( 2000, 2, 1, NULL),
(30000, 5, 1, 4),
(12000, 1, 1, 3),
( 8000, 2, 1, NULL),
(30000, 1, 1, 5),
( 4500, 2, 1, NULL),
(22000, 1, 1, 4),
(18000, 5, 1, 6),
(15000, 1, 2, 2),
( 9000, 2, 3, NULL),
(50000, 1, 1, 7),
( 1500, 2, 5, NULL),
(27000, 1, 1, 4),
( 6200, 2, 1, NULL),
(31000, 1, 1, 3),
( 4900, 2, 6, NULL),
(55000, 1, 1, 8);
GO

-- Customer（先创建客户，PrimaryAccountID 暂设为 NULL，稍后更新）
INSERT INTO Customer(
    UserLoginID, PrimaryAccountID,
    CustomerFirstName, CustomerMiddleInitial, CustomerLastName,
    CustomerAddress1, CustomerAddress2,
    City, State, ZipCode,
    EmailAddress,
    HomePhone, CellPhone, WorkPhone,
    SSN
) VALUES
(1, NULL, 'Alice', 'M', 'Lee',   'Addr1', NULL, 'Ottawa',   'ON', 'A1A1A1', 'alice@example.com', '1111111111','2222222222','3333333333','111111111'),
(2, NULL, 'Bob',   'K', 'Chan',  'Addr2', NULL, 'Hamilton', 'ON', 'B2B2B2', 'bob@example.com',   '1111111112','2222222223','3333333334','222222222'),
(3, NULL, 'Carol', 'P', 'Zhou',  'Addr3', NULL, 'Vancouver','BC', 'C3C3C3', 'carol@example.com', '1111111113','2222222224','3333333335','333333333'),
(4, NULL, 'David', 'R', 'Wu',    'Addr4', NULL, 'London',   'ON', 'D4D4D4', 'david@example.com', '1111111114','2222222225','3333333336','444444444'),
(5, NULL, 'Eric',  'S', 'Tang',  'Addr5', NULL, 'Calgary',  'AB', 'E5E5E5', 'eric@example.com',  '1111111115','2222222226','3333333337','555555555'),
(6, NULL, 'Frank', 'E', 'Taylor', 'Addr1', NULL, 'Toronto', 'ON', 'F1F1F1','frank@example.com','1111111116','2222222227','3333333338','666666666'),
(7, NULL, 'Grace', 'R', 'Miller','Addr2', NULL, 'Ottawa','ON','G2G2G2','grace@example.com','1111111117','2222222228','3333333339','777777777'),
(8, NULL, 'Helen', NULL,'Scott', 'Addr3', NULL,'Hamilton','ON','H3H3H3','helen@example.com','1111111118','2222222229','3333333340','888888888'),
(9, NULL, 'Ian',   'K','Xu',     'Addr4', NULL,'London','ON','I4I4I4','ian@example.com','1111111119','2222222230','3333333341','999999999'),
(10,NULL,'Jane',  'S','Ho',     'Addr5', NULL,'Vancouver','BC','J5J5J5','jane@example.com','1111111120','2222222231','3333333342','112233445'),
(11,NULL,'Kevin', NULL,'Fang',  'Addr6', NULL,'Calgary','AB','K6K6K6','kevin@example.com','1111111121','2222222232','3333333343','998877665'),
(12,NULL,'Laura', 'H','Chen',   'Addr7', NULL,'Edmonton','AB','L7L7L7','laura@example.com','1111111122','2222222233','3333333344','234567891'),
(13,NULL,'Mario', 'T','Rossi',  'Addr8', NULL,'Toronto','ON','M8M8M8','mario@example.com','1111111123','2222222234','3333333345','345678912'),
(14,NULL,'Nina',  'P','Kim',    'Addr9', NULL,'Ottawa','ON','N9N9N9','nina@example.com','1111111124','2222222235','3333333346','456789123'),
(15,NULL,'Oliver','Q','Singh',  'Addr10',NULL,'London','ON','O0O0O0','oliver@example.com','1111111125','2222222236','3333333347','567891234');
GO

-- CustomerAccount：简单一一对应
INSERT INTO CustomerAccount(CustomerID, AccountID) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5),
(6,6),
(7,7),
(8,8),
(9,9),
(10,10),
(11,11),
(12,12),
(13,13),
(14,14),
(15,15);
GO

-- 更新 Customer.PrimaryAccountID
UPDATE Customer SET PrimaryAccountID = A.AccountID
FROM Customer C
JOIN CustomerAccount CA ON C.CustomerID = CA.CustomerID
JOIN Account A ON CA.AccountID = A.AccountID;
GO

-- LoginAccount：登录与账户对应
INSERT INTO LoginAccount(UserLoginID, AccountID) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5),
(6,6),
(7,7),
(8,8),
(9,9),
(10,10),
(11,11),
(12,12),
(13,13),
(14,14),
(15,15);
GO

-- LoginErrorLog
INSERT INTO LoginErrorLog(ErrorTime, UserLoginID, ErrorMessage, ErrorDetailsXML) VALUES
('2015-06-04T07:30:56', 1, 'Bad connection',      '<error code="NET01"/>'),
('2018-06-09T12:34:57', 2, 'Invalid user',        '<error code="AUTH01"/>'),
('2016-04-05T02:14:00', 3, 'Wrong password',      '<error code="AUTH02"/>'),
('2014-07-05T05:56:59', 4, 'Server issue',        '<error code="SYS01"/>'),
('2009-10-12T08:34:15', 5, 'Datacenter outage',   '<error code="SYS02"/>'),
('2023-11-01',  8,  'Session timeout',                '<e code="NEW03"/>'),
('2023-10-11',  9,  'Geo-restricted login',           '<e code="NEW04"/>'),
('2022-09-10', 10,  'User disabled',                  '<e code="NEW05"/>');
GO

-- FailedTransactionLog（示例）
INSERT INTO FailedTransactionLog(FailedTransactionErrorTypeID, AccountID, CustomerID, FailedTransactionErrorTime, FailedTransactionErrorXML) VALUES
(1, 1, 1, '2015-06-04T07:30:56', '<fail reason="Insufficient funds"/>'),
(2, 2, 2, '2018-06-09T12:34:57', '<fail reason="Daily limit reached"/>'),
(3, 3, 3, '2016-04-05T02:14:00', '<fail reason="Invalid denomination"/>'),
(4, 4, 4, '2014-07-05T05:56:59', '<fail reason="Account locked"/>'),
(5, 5, 5, '2009-10-12T08:34:15', '<fail reason="System error"/>'),
(1,  6, 6, '2023-01-01', '<f reason="no funds" />'),
(2,  7, 7, '2023-01-02', '<f reason="withdraw limit" />'),
(3,  8, 8, '2023-01-03', '<f reason="denomination" />'),
(4,  9, 9, '2023-01-04', '<f reason="account lock" />'),
(5, 10,10, '2023-01-05', '<f reason="system" />');
GO

-- OverDraftLog
INSERT INTO OverDraftLog(AccountID, OverDraftDate, OverDraftAmount, OverDraftTransactionXML) VALUES
(1, '2015-06-04T07:30:56', 100, '<od account="1" />'),
(2, '2018-06-09T12:34:57', 200, '<od account="2" />'),
(3, '2016-04-05T02:14:00', 300, '<od account="3" />'),
(4, '2014-07-05T05:56:59', 400, '<od account="4" />'),
(5, '2009-10-12T08:34:15', 500, '<od account="5" />'),
(6, '2023-01-01', 120, '<od />'),
(7, '2023-01-02', 180, '<od />'),
(8, '2023-01-03', 240, '<od />'),
(9, '2023-01-04', 300, '<od />'),
(10,'2023-01-05', 360, '<od />');
GO

-- TransactionLog
INSERT INTO TransactionLog(TransactionDate, TransactionTypeID, TransactionAmount, NewBalance, AccountID, CustomerID, EmployeeID, UserLoginID) VALUES
('2015-06-04T07:30:56', 1,  500, 15500, 1, 1, 1, 1),
('2018-06-09T12:34:57', 2,  200,  4800, 2, 2, 2, 2),
('2016-04-05T02:14:00', 3, 1000,  9000, 3, 3, 3, 3),
('2014-07-05T05:56:59', 4,  300,  1700, 4, 4, 4, 4),
('2009-10-12T08:34:15', 1, 5000, 35000, 5, 5, 5, 5),

('2023-01-10',1, 600, 12600, 11,11,1,11),
('2023-01-11',2, 700,  8300, 12,12,2,12),
('2023-01-12',3, 800, 10800, 13,13,3,13),
('2023-01-13',4, 500,  4400, 14,14,4,14),
('2023-01-14',5,  50,  5050, 15,15,5,15);
GO




