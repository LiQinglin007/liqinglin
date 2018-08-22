/*
Navicat SQL Server Data Transfer

Source Server         : environManage
Source Server Version : 100000
Source Host           : 192.168.5.55:1433
Source Database       : EnvironManage
Source Schema         : dbo

Target Server Type    : SQL Server
Target Server Version : 100000
File Encoding         : 65001

Date: 2018-07-09 16:16:09
*/


-- ----------------------------
-- Table structure for TLoginUser
-- ----------------------------
DROP TABLE [dbo].[TLoginUser]
GO
CREATE TABLE [dbo].[TLoginUser] (
[LoginName] varchar(10) NULL ,
[UserName] nvarchar(10) NULL ,
[LoginPwd] varchar(50) NULL ,
[LoginPwdMD5] varchar(50) NULL ,
[LoginCount] int NULL ,
[LastLoginTime] datetime NULL ,
[SystemRole] int NULL ,
[CompanyId] varchar(38) NULL ,
[IsDel] bit NULL DEFAULT ((0)) ,
[Id] varchar(38) NOT NULL DEFAULT (newid()) ,
[CreateUserId] varchar(38) NULL ,
[CreateTime] datetime NULL DEFAULT (getdate()) ,
[CreatePC] varchar(100) NULL ,
[ModifyUserId] varchar(38) NULL ,
[ModifyPC] varchar(100) NULL ,
[ModifyTime] datetime NULL DEFAULT (getdate()) 
)


GO
IF ((SELECT COUNT(*) from fn_listextendedproperty('MS_Description', 
'SCHEMA', N'dbo', 
'TABLE', N'TLoginUser', 
NULL, NULL)) > 0) 
EXEC sp_updateextendedproperty @name = N'MS_Description', @value = N'登陆用户表'
, @level0type = 'SCHEMA', @level0name = N'dbo'
, @level1type = 'TABLE', @level1name = N'TLoginUser'
ELSE
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'登陆用户表'
, @level0type = 'SCHEMA', @level0name = N'dbo'
, @level1type = 'TABLE', @level1name = N'TLoginUser'
GO
IF ((SELECT COUNT(*) from fn_listextendedproperty('MS_Description', 
'SCHEMA', N'dbo', 
'TABLE', N'TLoginUser', 
'COLUMN', N'SystemRole')) > 0) 
EXEC sp_updateextendedproperty @name = N'MS_Description', @value = N'系统角色'
, @level0type = 'SCHEMA', @level0name = N'dbo'
, @level1type = 'TABLE', @level1name = N'TLoginUser'
, @level2type = 'COLUMN', @level2name = N'SystemRole'
ELSE
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'系统角色'
, @level0type = 'SCHEMA', @level0name = N'dbo'
, @level1type = 'TABLE', @level1name = N'TLoginUser'
, @level2type = 'COLUMN', @level2name = N'SystemRole'
GO

-- ----------------------------
-- Indexes structure for table TLoginUser
-- ----------------------------

-- ----------------------------
-- Primary Key structure for table TLoginUser
-- ----------------------------
ALTER TABLE [dbo].[TLoginUser] ADD PRIMARY KEY ([Id])
GO
