-- 酒店人事一体化综合管理系统数据库设计与开发
-- 运行环境：MySQL 8.0
-- 建议先执行本文件，再依次执行 02 ~ 07 号脚本

DROP DATABASE IF EXISTS hotel_hr_system;
CREATE DATABASE hotel_hr_system
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE hotel_hr_system;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 1;
