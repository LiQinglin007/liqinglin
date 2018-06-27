/*
Navicat MySQL Data Transfer

Source Server         : nbaSql
Source Server Version : 50512
Source Host           : localhost:3306
Source Database       : editormi

Target Server Type    : MYSQL
Target Server Version : 50512
File Encoding         : 65001

Date: 2018-06-27 08:43:28
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for banner
-- ----------------------------
DROP TABLE IF EXISTS `banner`;
CREATE TABLE `banner` (
  `banner_id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '图片id',
  `banner_url` varchar(200) NOT NULL COMMENT '图片地址',
  `banner_weight` smallint(2) NOT NULL DEFAULT '0' COMMENT '权重  数字越大越在前边显示',
  `banner_web_url` varchar(200) DEFAULT NULL COMMENT '外部连接',
  `banner_del` smallint(1) DEFAULT '0' COMMENT '是否被删除  0：没删除  1：被删除了',
  PRIMARY KEY (`banner_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for collection
-- ----------------------------
DROP TABLE IF EXISTS `collection`;
CREATE TABLE `collection` (
  `collection_id` smallint(11) NOT NULL AUTO_INCREMENT COMMENT '收藏Id',
  `user_id` int(11) NOT NULL COMMENT '用户id',
  `collection_type` smallint(1) NOT NULL COMMENT '收藏类型（0:工作室、1:服务）',
  `collection_content_id` int(11) DEFAULT NULL COMMENT '收藏内容的id',
  PRIMARY KEY (`collection_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for commodity
-- ----------------------------
DROP TABLE IF EXISTS `commodity`;
CREATE TABLE `commodity` (
  `commodity_id` int(11) NOT NULL AUTO_INCREMENT COMMENT '商品id',
  `studio_id` int(11) DEFAULT NULL COMMENT '工作室ID',
  `commodity_name` varchar(50) DEFAULT NULL COMMENT '商品名称',
  `commodity_pic` varchar(30) DEFAULT NULL COMMENT '商品图片',
  `commodity_pics` varchar(300) DEFAULT NULL COMMENT '商品详情图片',
  `commodity_original_price` float DEFAULT NULL COMMENT '商品原价',
  `commodity_present_price` float DEFAULT NULL COMMENT '商品现价',
  `commodity_type` smallint(1) DEFAULT NULL COMMENT '服务类型(1:查重、2:降重、3:速审)',
  `commodity_monthly_sales` int(11) DEFAULT '0' COMMENT '月销量',
  `commodity_collection_quantity` int(11) DEFAULT '0' COMMENT '收藏数量',
  `commodity_hot` smallint(1) DEFAULT '0' COMMENT '是否为热门服务  0:不是  1：热门',
  `commodity_del` smallint(1) NOT NULL DEFAULT '0' COMMENT '是否被删除  0：不被删除  1：被删除了',
  PRIMARY KEY (`commodity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for evaluate
-- ----------------------------
DROP TABLE IF EXISTS `evaluate`;
CREATE TABLE `evaluate` (
  `evaluate_id` int(11) NOT NULL AUTO_INCREMENT COMMENT '评价ID',
  `order_id` int(11) DEFAULT NULL COMMENT '工作室ID',
  `evaluate_conetnt` varchar(100) DEFAULT NULL COMMENT '评价内容',
  `evaluate_time` datetime DEFAULT NULL COMMENT '评论时间',
  `evaluate_score` smallint(1) NOT NULL DEFAULT '0' COMMENT '评分  1:好评  2：差评',
  PRIMARY KEY (`evaluate_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for feedback
-- ----------------------------
DROP TABLE IF EXISTS `feedback`;
CREATE TABLE `feedback` (
  `feedback_id` smallint(11) NOT NULL AUTO_INCREMENT COMMENT '反馈ID',
  `feedback_type` smallint(1) DEFAULT NULL COMMENT '反馈类型(0:意见 ; 1：bug)',
  `feedback_content` varchar(500) DEFAULT NULL COMMENT '反馈内容',
  `feedback_userId` int(11) DEFAULT NULL COMMENT '反馈用户',
  `feedback_time` datetime DEFAULT NULL COMMENT '反馈时间',
  PRIMARY KEY (`feedback_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for notice
-- ----------------------------
DROP TABLE IF EXISTS `notice`;
CREATE TABLE `notice` (
  `notice_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `notice_title` varchar(20) NOT NULL COMMENT '公告标题',
  `notice_content` varchar(500) NOT NULL COMMENT '公告内容',
  `notice_time` datetime DEFAULT NULL,
  `notice_del` smallint(1) DEFAULT '0' COMMENT '是否被删除  0：没删除  1：被删除了',
  PRIMARY KEY (`notice_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for order
-- ----------------------------
DROP TABLE IF EXISTS `order`;
CREATE TABLE `order` (
  `order_id` int(11) NOT NULL AUTO_INCREMENT COMMENT '订单id',
  `order_type` smallint(11) DEFAULT NULL COMMENT '订单类型(1:查重、2:降重、3:速审)',
  `order_state` smallint(11) DEFAULT NULL COMMENT '订单状态',
  `studio_id` int(11) DEFAULT NULL COMMENT '工作室id',
  `servlet_id` int(11) DEFAULT NULL COMMENT '服务id',
  `result_file_id` int(11) unsigned DEFAULT NULL COMMENT '检查结束的文件id',
  `user_file_Id` int(11) DEFAULT NULL COMMENT '文件id',
  `user_id` int(11) DEFAULT NULL COMMENT '用户id',
  `order_price` float DEFAULT '0' COMMENT '订单价格',
  `order_result` varchar(200) DEFAULT NULL COMMENT '检查结果',
  `order_sum_time` varchar(10) DEFAULT NULL COMMENT '本次检查用的时间',
  `create_time` datetime NOT NULL COMMENT '下单时间',
  `receipt_time` datetime DEFAULT NULL COMMENT '查稿时间',
  `confirm_time` datetime DEFAULT NULL COMMENT '确认时间(用户已经收到了)',
  `evaluate_time` datetime DEFAULT NULL COMMENT '评价时间',
  PRIMARY KEY (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for resultfile
-- ----------------------------
DROP TABLE IF EXISTS `resultfile`;
CREATE TABLE `resultfile` (
  `file_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `file_name` varchar(30) DEFAULT NULL COMMENT '文件名称',
  `author` varchar(10) NOT NULL COMMENT '作者',
  `author_degree` varchar(10) DEFAULT NULL COMMENT '作者学历',
  `downloadurl` varchar(200) DEFAULT NULL COMMENT '下载地址',
  `see_time` datetime DEFAULT NULL COMMENT '见刊时间',
  PRIMARY KEY (`file_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for statistics
-- ----------------------------
DROP TABLE IF EXISTS `statistics`;
CREATE TABLE `statistics` (
  `statistics_id` int(11) NOT NULL,
  `statistics_time` datetime DEFAULT NULL COMMENT '上次的统计时间',
  `statistics_type` smallint(1) DEFAULT NULL COMMENT '统计类型（0:工作室、1:服务）',
  `content_id` int(11) DEFAULT NULL COMMENT '工作室的id  或者是服务的id',
  `content_sum_number` int(11) DEFAULT NULL COMMENT '工作室/服务销售总数量',
  `content_sum_score` int(11) DEFAULT NULL COMMENT '当前工作室/服务的好评数',
  `content_sum_number_month` int(11) DEFAULT NULL COMMENT '当前工作室/服务的当前月累积销量',
  PRIMARY KEY (`statistics_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for studio
-- ----------------------------
DROP TABLE IF EXISTS `studio`;
CREATE TABLE `studio` (
  `studio_id` int(11) NOT NULL AUTO_INCREMENT COMMENT '工作室ID',
  `studio_name` varchar(30) DEFAULT NULL COMMENT '商铺名称',
  `studio_pic` varchar(30) DEFAULT NULL COMMENT '工作室图片',
  `studio_money` float DEFAULT '0' COMMENT '诚信保证金',
  `studio_phone` varchar(11) DEFAULT NULL COMMENT '工作室电话',
  `studio_monthly_sales` int(10) DEFAULT '0' COMMENT '月销量',
  `studio_QQ` varchar(15) DEFAULT NULL COMMENT '商铺QQ',
  `studio_briefIntroduction` varchar(100) DEFAULT NULL COMMENT '商铺简介',
  `studio_collection_nmuber` int(11) DEFAULT '0' COMMENT '收藏数量',
  `studio_del` smallint(1) NOT NULL DEFAULT '0' COMMENT '是否被删除  0：没删除  1：被删除了',
  `system_userid` int(10) DEFAULT NULL COMMENT '系统用户id',
  PRIMARY KEY (`studio_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for system
-- ----------------------------
DROP TABLE IF EXISTS `system`;
CREATE TABLE `system` (
  `system_userid` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `system_user_loginname` varchar(255) DEFAULT NULL,
  `system_user_password` varchar(255) DEFAULT NULL,
  `system_user_type` smallint(2) DEFAULT NULL COMMENT '用户类型  1：超级管理员  2：工作室',
  `system_user_del` smallint(1) DEFAULT '0' COMMENT '是否被删除  0：没删除  1：被删除了',
  PRIMARY KEY (`system_userid`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for user
-- ----------------------------
DROP TABLE IF EXISTS `user`;
CREATE TABLE `user` (
  `user_id` int(11) NOT NULL AUTO_INCREMENT COMMENT '用户id',
  `user_name` varchar(100) DEFAULT NULL COMMENT '用户昵称',
  `user_password` varchar(50) NOT NULL COMMENT '密码',
  `user_pic` varchar(100) DEFAULT NULL COMMENT '头像',
  `user_balance` float DEFAULT '0' COMMENT '账户余额',
  `user_phone` varchar(15) NOT NULL DEFAULT '15284224244' COMMENT '电话（登陆名称）',
  `user_school` varchar(20) DEFAULT NULL COMMENT '学校',
  `user_job` varchar(10) DEFAULT NULL COMMENT '职业',
  `user_education` varchar(5) DEFAULT NULL COMMENT '学历',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `userPhone` (`user_phone`)
) ENGINE=InnoDB AUTO_INCREMENT=36 DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for userfile
-- ----------------------------
DROP TABLE IF EXISTS `userfile`;
CREATE TABLE `userfile` (
  `file_id` int(11) NOT NULL AUTO_INCREMENT COMMENT '文件id',
  `user_id` int(11) NOT NULL COMMENT '用户id',
  `file_name` varchar(30) DEFAULT NULL COMMENT '文件名称',
  `file_url` varchar(50) DEFAULT NULL COMMENT '文件地址',
  PRIMARY KEY (`file_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
