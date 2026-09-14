-- 医院门诊管理系统：表结构设计
-- 覆盖角色、用户、科室、医生、排班、患者档案、挂号、药品、处方、收费退费、操作日志

USE hospital_outpatient;

DROP TABLE IF EXISTS operation_logs;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS prescription_items;
DROP TABLE IF EXISTS prescriptions;
DROP TABLE IF EXISTS medicines;
DROP TABLE IF EXISTS registrations;
DROP TABLE IF EXISTS doctor_schedules;
DROP TABLE IF EXISTS patients;
DROP TABLE IF EXISTS doctors;
DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS roles;

-- 1. 系统角色表
CREATE TABLE roles (
  role_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '角色编号',
  role_code VARCHAR(30) NOT NULL UNIQUE COMMENT '角色编码',
  role_name VARCHAR(50) NOT NULL COMMENT '角色名称',
  description VARCHAR(200) NULL COMMENT '角色说明'
) COMMENT='系统角色表';

-- 2. 系统用户表（含登录账号，医生/挂号员/收费员/管理员统一管理）
CREATE TABLE users (
  user_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '用户编号',
  user_no VARCHAR(30) NOT NULL UNIQUE COMMENT '工号',
  user_name VARCHAR(50) NOT NULL COMMENT '姓名',
  gender ENUM('男','女') NOT NULL COMMENT '性别',
  department_id INT NULL COMMENT '所属科室',
  role_id INT NOT NULL COMMENT '角色编号',
  phone VARCHAR(20) NOT NULL UNIQUE COMMENT '联系电话',
  username VARCHAR(50) NOT NULL UNIQUE COMMENT '登录名',
  password_hash VARCHAR(128) NOT NULL COMMENT '密码哈希',
  account_status ENUM('启用','锁定') NOT NULL DEFAULT '启用' COMMENT '账号状态',
  last_login_at DATETIME NULL COMMENT '最近登录时间',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建档时间',
  CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(role_id)
) COMMENT='系统用户表';

-- 3. 科室表
CREATE TABLE departments (
  department_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '科室编号',
  department_code VARCHAR(20) NOT NULL UNIQUE COMMENT '科室编码',
  department_name VARCHAR(50) NOT NULL UNIQUE COMMENT '科室名称',
  description VARCHAR(200) NULL COMMENT '科室说明',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
) COMMENT='门诊科室表';

ALTER TABLE users
  ADD CONSTRAINT fk_users_department FOREIGN KEY (department_id) REFERENCES departments(department_id);

-- 4. 医生档案表（扩展用户，含职称、专长、挂号费、限号）
CREATE TABLE doctors (
  doctor_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '医生编号',
  user_id INT NOT NULL UNIQUE COMMENT '关联用户',
  doctor_no VARCHAR(30) NOT NULL UNIQUE COMMENT '医生工号',
  title VARCHAR(30) NOT NULL DEFAULT '主治医师' COMMENT '职称',
  specialty VARCHAR(100) NULL COMMENT '专业专长',
  consultation_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '挂号费',
  max_daily_registrations INT NOT NULL DEFAULT 30 COMMENT '每日限号',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  CONSTRAINT fk_doctors_user FOREIGN KEY (user_id) REFERENCES users(user_id),
  CONSTRAINT ck_doctors_fee CHECK (consultation_fee >= 0),
  CONSTRAINT ck_doctors_limit CHECK (max_daily_registrations > 0)
) COMMENT='医生档案表';

-- 5. 医生排班表
CREATE TABLE doctor_schedules (
  schedule_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '排班编号',
  doctor_id INT NOT NULL COMMENT '医生编号',
  work_date DATE NOT NULL COMMENT '出诊日期',
  shift_type ENUM('上午','下午','全天') NOT NULL COMMENT '班次',
  clinic_room VARCHAR(20) NULL COMMENT '诊室',
  max_registrations INT NOT NULL DEFAULT 20 COMMENT '号源数',
  registered_count INT NOT NULL DEFAULT 0 COMMENT '已挂号数',
  schedule_status ENUM('正常','停诊') NOT NULL DEFAULT '正常' COMMENT '排班状态',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  CONSTRAINT uk_schedule_doctor_date UNIQUE (doctor_id, work_date, shift_type),
  CONSTRAINT fk_schedules_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  CONSTRAINT ck_schedules_max CHECK (max_registrations > 0),
  CONSTRAINT ck_schedules_reg CHECK (registered_count >= 0)
) COMMENT='医生排班表';

-- 6. 患者档案表
CREATE TABLE patients (
  patient_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '患者编号',
  patient_no VARCHAR(30) NOT NULL UNIQUE COMMENT '病历号',
  patient_name VARCHAR(50) NOT NULL COMMENT '姓名',
  gender ENUM('男','女') NOT NULL COMMENT '性别',
  birth_date DATE NULL COMMENT '出生日期',
  id_card VARCHAR(30) NOT NULL UNIQUE COMMENT '身份证号',
  phone VARCHAR(20) NOT NULL UNIQUE COMMENT '联系电话',
  address VARCHAR(200) NULL COMMENT '联系地址',
  blood_type ENUM('A','B','AB','O','未知') NOT NULL DEFAULT '未知' COMMENT '血型',
  medical_history VARCHAR(500) NULL COMMENT '既往病史',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建档时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) COMMENT='患者档案表';

-- 7. 挂号表
CREATE TABLE registrations (
  registration_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '挂号编号',
  reg_no VARCHAR(40) NOT NULL UNIQUE COMMENT '挂号单号',
  patient_id INT NOT NULL COMMENT '患者编号',
  doctor_id INT NOT NULL COMMENT '医生编号',
  department_id INT NOT NULL COMMENT '科室编号',
  reg_date DATE NOT NULL COMMENT '挂号日期',
  reg_type ENUM('普通号','专家号') NOT NULL DEFAULT '普通号' COMMENT '号别',
  reg_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '挂号费',
  queue_no INT NOT NULL COMMENT '排队号',
  visit_status ENUM('待就诊','就诊中','已就诊','已退号') NOT NULL DEFAULT '待就诊' COMMENT '就诊状态',
  operator_id INT NOT NULL COMMENT '挂号员',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '挂号时间',
  CONSTRAINT fk_reg_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  CONSTRAINT fk_reg_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  CONSTRAINT fk_reg_department FOREIGN KEY (department_id) REFERENCES departments(department_id),
  CONSTRAINT fk_reg_operator FOREIGN KEY (operator_id) REFERENCES users(user_id),
  CONSTRAINT ck_reg_fee CHECK (reg_fee >= 0),
  CONSTRAINT ck_reg_queue CHECK (queue_no > 0)
) COMMENT='门诊挂号表';

-- 8. 药品目录表
CREATE TABLE medicines (
  medicine_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '药品编号',
  medicine_code VARCHAR(30) NOT NULL UNIQUE COMMENT '药品编码',
  medicine_name VARCHAR(100) NOT NULL COMMENT '药品名称',
  specification VARCHAR(100) NULL COMMENT '规格',
  unit VARCHAR(20) NOT NULL DEFAULT '盒' COMMENT '单位',
  manufacturer VARCHAR(100) NULL COMMENT '生产厂家',
  unit_price DECIMAL(10,2) NOT NULL COMMENT '单价',
  stock_quantity INT NOT NULL DEFAULT 0 COMMENT '库存数量',
  medicine_type ENUM('西药','中成药','注射剂','外用') NOT NULL DEFAULT '西药' COMMENT '药品类型',
  status ENUM('启用','停用') NOT NULL DEFAULT '启用' COMMENT '药品状态',
  CONSTRAINT ck_medicines_price CHECK (unit_price >= 0),
  CONSTRAINT ck_medicines_stock CHECK (stock_quantity >= 0)
) COMMENT='药品目录表';

-- 9. 处方表
CREATE TABLE prescriptions (
  prescription_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '处方编号',
  prescription_no VARCHAR(40) NOT NULL UNIQUE COMMENT '处方号',
  patient_id INT NOT NULL COMMENT '患者编号',
  doctor_id INT NOT NULL COMMENT '开方医生',
  registration_id INT NULL COMMENT '关联挂号',
  prescribe_date DATE NOT NULL COMMENT '开方日期',
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '处方总金额',
  prescription_status ENUM('待收费','已收费','已退费','已作废') NOT NULL DEFAULT '待收费' COMMENT '处方状态',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '开方时间',
  CONSTRAINT fk_pres_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  CONSTRAINT fk_pres_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  CONSTRAINT fk_pres_registration FOREIGN KEY (registration_id) REFERENCES registrations(registration_id),
  CONSTRAINT ck_pres_amount CHECK (total_amount >= 0)
) COMMENT='处方表';

-- 10. 处方明细表
CREATE TABLE prescription_items (
  item_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '明细编号',
  prescription_id INT NOT NULL COMMENT '处方编号',
  medicine_id INT NOT NULL COMMENT '药品编号',
  medicine_name VARCHAR(100) NOT NULL COMMENT '药品名称（冗余快照）',
  quantity INT NOT NULL COMMENT '数量',
  unit_price DECIMAL(10,2) NOT NULL COMMENT '单价',
  amount DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED COMMENT '金额',
  dosage VARCHAR(200) NULL COMMENT '用法用量',
  CONSTRAINT fk_items_prescription FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id),
  CONSTRAINT fk_items_medicine FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id),
  CONSTRAINT ck_items_quantity CHECK (quantity > 0),
  CONSTRAINT ck_items_price CHECK (unit_price >= 0)
) COMMENT='处方明细表';

-- 11. 收费退费记录表
CREATE TABLE payments (
  payment_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '收费编号',
  payment_no VARCHAR(40) NOT NULL UNIQUE COMMENT '收费单号',
  patient_id INT NOT NULL COMMENT '患者编号',
  registration_id INT NULL COMMENT '关联挂号（挂号费）',
  prescription_id INT NULL COMMENT '关联处方（药品费）',
  payment_type ENUM('挂号费','药品费','检查费') NOT NULL COMMENT '收费类型',
  pay_amount DECIMAL(10,2) NOT NULL COMMENT '收费金额',
  pay_method ENUM('现金','微信','支付宝','医保') NOT NULL DEFAULT '微信' COMMENT '支付方式',
  pay_status ENUM('已收费','已退费') NOT NULL DEFAULT '已收费' COMMENT '收费状态',
  operator_id INT NOT NULL COMMENT '收费员',
  pay_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '收费时间',
  refund_time DATETIME NULL COMMENT '退费时间',
  refund_operator_id INT NULL COMMENT '退费操作员',
  refund_reason VARCHAR(200) NULL COMMENT '退费原因',
  CONSTRAINT fk_pay_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  CONSTRAINT fk_pay_registration FOREIGN KEY (registration_id) REFERENCES registrations(registration_id),
  CONSTRAINT fk_pay_prescription FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id),
  CONSTRAINT fk_pay_operator FOREIGN KEY (operator_id) REFERENCES users(user_id),
  CONSTRAINT fk_pay_refund_operator FOREIGN KEY (refund_operator_id) REFERENCES users(user_id),
  CONSTRAINT ck_pay_amount CHECK (pay_amount >= 0)
) COMMENT='收费退费记录表';

-- 12. 操作日志表
CREATE TABLE operation_logs (
  log_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '日志编号',
  user_id INT NULL COMMENT '操作用户',
  business_type VARCHAR(50) NOT NULL COMMENT '业务类型',
  business_id INT NULL COMMENT '业务编号',
  operation_content VARCHAR(500) NOT NULL COMMENT '操作内容',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  CONSTRAINT fk_logs_user FOREIGN KEY (user_id) REFERENCES users(user_id)
) COMMENT='系统操作日志表';
