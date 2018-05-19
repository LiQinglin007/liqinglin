#创建球队表
CREATE TABLE team(
#球队编号 整型 无符号 自增  主键
teamId INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, 
#球队名称  字符串  不能为空  唯一
teamName VARCHAR(20) NOT NULL UNIQUE,
#球队年龄  整型 无符号   可以为空
teamAge TINYINT  UNSIGNED NULL ,
#总场次
toalMatch INT NOT NULL,
#胜场 整型  不能为空
victoryNumber INT NOT NULL ,
#冠军数量
championNumber INT NOT NULL,
#球馆名称
ballHall VARCHAR(40) 
);

#创建教练表
CREATE TABLE coach(
#教练ID  整型  无符号  自增  主键
coachId INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
#教练名称   字符串  不能为空  唯一
coachName VARCHAR(20) NOT NULL UNIQUE,
#总场次
toalMatch INT NOT NULL DEFAULT 0,
#胜场 整型  不能为空
victoryNumber INT NOT NULL DEFAULT 0,
#冠军数量
championNumber INT NOT NULL DEFAULT 0,
#球队ID
teamId INT UNSIGNED  NOT NULL,

FOREIGN KEY(teamId) REFERENCES team (teamId)  ON DELETE CASCADE
);

#修改表名
ALTER TABLE team RENAME TO teamUpdate;
ALTER TABLE teamUpdate RENAME TO team;

#查看表结构
SHOW COLUMNS FROM team;
#添加列在最开始
ALTER TABLE team ADD testAdd VARCHAR(20) FIRST
#添加列在最后边
ALTER TABLE team ADD testAddLast VARCHAR(20) 
#添加列在某一列后边
ALTER TABLE team ADD testAddCenter VARCHAR(20)  AFTER teamName
#添加多列(这个不能设置插入的位置，只能插入到最后边)
ALTER TABLE team ADD testAddList1 VARCHAR(20),ADD testAddList2 VARCHAR(20),ADD testAddList3 VARCHAR(20) 

#查看表结构
SHOW COLUMNS FROM team;
#删除列
ALTER TABLE team DROP testAdd 
#批量删除列
ALTER TABLE team DROP testAddList1, DROP testAddList2, DROP testAddList3

#结合使用
ALTER TABLE team DROP testAddLast, ADD testAddNewLast VARCHAR(20) 

#修改数据表
#把某个字段移动到最开始
ALTER TABLE team MODIFY testAddNewLast VARCHAR(20) FIRST
#查看表结构
SHOW COLUMNS FROM team;
#修改字段属性
ALTER TABLE team MODIFY testAddNewLast VARCHAR(10) DEFAULT "小米"

 
#创建测试表
CREATE TABLE test(
#ID  整型 
testId INT ,
#名称   字符串  
testName VARCHAR(20) 
);


#插入
INSERT INTO team VALUES(NULL,"马刺",10,100,90,5,"AT&T中心");
INSERT INTO team VALUES(NULL,"勇士",10,100,90,5,"甲骨文中心");
INSERT INTO team(teamId,teamName,teamAge,toalMatch,victoryNumber,championNumber) VALUES(NULL,"凯尔特人",10,100,89,4);
INSERT INTO team(teamId,teamName,teamAge,toalMatch,victoryNumber,championNumber) VALUES(NULL,"火箭",10,100,90,5);
#批量插入
INSERT INTO team(teamId,teamName,teamAge,toalMatch,victoryNumber,championNumber) VALUES(NULL,"老鹰",10,100,90,5),(NULL,"黄蜂",10,100,90,5),(NULL,"鹈鹕",10,100,90,5);
INSERT INTO team VALUES(NULL,"公牛",10,100,90,5,"联合中心"),(NULL,"骑士",10,100,90,5,"速贷球馆"),(NULL,"灰熊",10,100,90,5,"联邦快递球馆");
#插入教练表
INSERT INTO coach(coachId,coachName,championNumber,teamId) VALUES(NULL,"波波维奇",5,(SELECT teamId FROM team WHERE team.`teamName`='马刺'));
INSERT INTO coach(coachId,coachName,championNumber,teamId) VALUES(NULL,"史蒂文斯",0,(SELECT teamId FROM team WHERE team.`teamName`='凯尔特人'));

#模糊删除
DELETE FROM team WHERE team.`teamName` LIKE '马刺%'


#查询全部
SELECT * FROM team;
SELECT * FROM coach;
#条件查询
SELECT teamId FROM team WHERE team.`teamName`='马刺'


#删除表
DROP TABLE team ;
DROP TABLE coach ;