-- 医院门诊管理系统（对标小型 HIS 门诊业务）数据库设计与开发
-- 运行环境：MySQL 8.0 / 8.4
-- 建议先执行本文件，再依次执行 02 ~ 07 号脚本

DROP DATABASE IF EXISTS hospital_outpatient;
CREATE DATABASE hospital_outpatient
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE hospital_outpatient;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 1;
