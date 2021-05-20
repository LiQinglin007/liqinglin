### 基本数据类型

##### VARCHAR

这个在oracle中不适合使用： 存放定長的字符数据，最长2000個字符； 

##### VARCHAR2

VARCHAR2是Oracle提供的特定数据类型，Oracle可以保证VARCHAR2在任何版本中该数据类型都可以向上和向下兼容 VARCHAR2(10)的话，则只能存进5个汉字，英文则可以存10个  ； 存放可变长字符数据，最大长度为4000字符。 

#####  NVARCHAR2 

  NVARCHAR2(10)是可以存进去10个汉字的，如果用来存英文也只能存10个字符 
  
#####  LOB--大型对象

 BLOB:二进制大型文件，可存储字节流数据(影像等)<br>
 CLOB：可存储大数据量内容,适用于存储文本型内容<br>
 这个查询的时候返回的不是String类型，需要使用TO_CHAR转换一下
 ```
 select  TO_CHAR(Test.OTHER_CONTROL)  OTHERCS from Test
 ```




### 修改表结构

```sql
-- 操作AA_TEST表
INSERT into AA_TEST VALUES('asdasd');
-- 新增字段 可为空，默认值为null
ALTER TABLE AA_TEST add  TestAA1  VARCHAR2(30) default '' ;
--新增字段 不可为空，默认值为123
ALTER TABLE AA_TEST add  TestAA2  VARCHAR2(30) default '123' not null ; 
-- 修改字段名称 把TestAA2--->TestAA3
ALTER TABLE AA_TEST rename column TestAA2 to TestAA3;
-- 删除字段
ALTER TABLE AA_TEST drop column TestAA3;
-- 把一个Varchar2(30)-->VARCHAR2(50)
ALTER TABLE AA_TEST MODIFY TestAA1 VARCHAR2(50);
-- 把一个String转换成number,就会报错
ALTER TABLE AA_TEST MODIFY TestAA NUMBER(10);
```

### 条件查询

```sql
--查询id,number的描述
select "Test"  ,
case  	when  AA_TEST.TESTAA>90   then '优秀'
        when AA_TEST.TESTAA >80  then '良好'
        else '一般'
end as describe
from AA_TEST
```



