-- 酒店人事一体化综合管理系统：表结构设计
-- 本脚本包含部门、人事、客房、入住、工单、考勤、薪资、日志等核心数据表

USE hotel_hr_system;

DROP TABLE IF EXISTS operation_logs;
DROP TABLE IF EXISTS salary_payments;
DROP TABLE IF EXISTS salary_records;
DROP TABLE IF EXISTS overtime_records;
DROP TABLE IF EXISTS leave_records;
DROP TABLE IF EXISTS attendance_records;
DROP TABLE IF EXISTS schedules;
DROP TABLE IF EXISTS work_orders;
DROP TABLE IF EXISTS consumption_items;
DROP TABLE IF EXISTS checkin_orders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS room_types;
DROP TABLE IF EXISTS user_accounts;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS positions;
DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS roles;

CREATE TABLE departments (
  department_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '部门编号',
  department_name VARCHAR(50) NOT NULL UNIQUE COMMENT '部门名称',
  manager_employee_id INT NULL COMMENT '部门负责人',
  description VARCHAR(200) NULL COMMENT '部门说明',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
) COMMENT='部门表';

CREATE TABLE positions (
  position_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '岗位编号',
  department_id INT NOT NULL COMMENT '所属部门',
  position_name VARCHAR(50) NOT NULL COMMENT '岗位名称',
  base_salary DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '岗位默认基本工资',
  performance_rate DECIMAL(8,2) NOT NULL DEFAULT 0.00 COMMENT '默认绩效单价或比例',
  CONSTRAINT uk_position_department UNIQUE (department_id, position_name),
  CONSTRAINT fk_positions_department FOREIGN KEY (department_id) REFERENCES departments(department_id),
  CONSTRAINT ck_positions_salary CHECK (base_salary >= 0),
  CONSTRAINT ck_positions_rate CHECK (performance_rate >= 0)
) COMMENT='岗位表';

CREATE TABLE roles (
  role_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '角色编号',
  role_code VARCHAR(30) NOT NULL UNIQUE COMMENT '角色编码',
  role_name VARCHAR(50) NOT NULL COMMENT '角色名称',
  description VARCHAR(200) NULL COMMENT '角色说明'
) COMMENT='系统角色表';

CREATE TABLE employees (
  employee_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '员工编号',
  employee_no VARCHAR(30) NOT NULL UNIQUE COMMENT '工号',
  employee_name VARCHAR(50) NOT NULL COMMENT '姓名',
  gender ENUM('男','女') NOT NULL COMMENT '性别',
  department_id INT NOT NULL COMMENT '所属部门',
  position_id INT NOT NULL COMMENT '岗位',
  phone VARCHAR(20) NOT NULL UNIQUE COMMENT '联系电话',
  id_card VARCHAR(30) NOT NULL UNIQUE COMMENT '证件号码',
  hire_date DATE NOT NULL COMMENT '入职日期',
  leave_date DATE NULL COMMENT '离职日期',
  employment_status ENUM('在职','离职') NOT NULL DEFAULT '在职' COMMENT '任职状态',
  base_salary DECIMAL(10,2) NOT NULL COMMENT '基本工资',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建档时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  CONSTRAINT fk_employees_department FOREIGN KEY (department_id) REFERENCES departments(department_id),
  CONSTRAINT fk_employees_position FOREIGN KEY (position_id) REFERENCES positions(position_id),
  CONSTRAINT ck_employees_salary CHECK (base_salary >= 0),
  CONSTRAINT ck_employees_leave CHECK (leave_date IS NULL OR leave_date >= hire_date)
) COMMENT='员工档案表';

ALTER TABLE departments
  ADD CONSTRAINT fk_departments_manager FOREIGN KEY (manager_employee_id) REFERENCES employees(employee_id);

CREATE TABLE user_accounts (
  account_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '账号编号',
  employee_id INT NOT NULL UNIQUE COMMENT '关联员工',
  role_id INT NOT NULL COMMENT '角色编号',
  username VARCHAR(50) NOT NULL UNIQUE COMMENT '登录名',
  password_hash VARCHAR(128) NOT NULL COMMENT '密码哈希，课程设计中可用明文模拟',
  account_status ENUM('启用','锁定') NOT NULL DEFAULT '启用' COMMENT '账号状态',
  last_login_at DATETIME NULL COMMENT '最近登录时间',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  CONSTRAINT fk_accounts_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
  CONSTRAINT fk_accounts_role FOREIGN KEY (role_id) REFERENCES roles(role_id)
) COMMENT='系统登录账号表';

CREATE TABLE room_types (
  room_type_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '房型编号',
  type_name VARCHAR(50) NOT NULL UNIQUE COMMENT '房型名称',
  standard_price DECIMAL(10,2) NOT NULL COMMENT '标准房价',
  max_guests INT NOT NULL DEFAULT 2 COMMENT '最大入住人数',
  facilities VARCHAR(300) NULL COMMENT '配套设施',
  CONSTRAINT ck_room_types_price CHECK (standard_price >= 0),
  CONSTRAINT ck_room_types_guests CHECK (max_guests > 0)
) COMMENT='房型表';

CREATE TABLE rooms (
  room_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '客房编号',
  room_no VARCHAR(20) NOT NULL UNIQUE COMMENT '房号',
  floor_no INT NOT NULL COMMENT '楼层',
  room_type_id INT NOT NULL COMMENT '房型编号',
  room_status ENUM('空闲','入住','维修','待打扫') NOT NULL DEFAULT '空闲' COMMENT '客房状态',
  remark VARCHAR(200) NULL COMMENT '备注',
  CONSTRAINT fk_rooms_type FOREIGN KEY (room_type_id) REFERENCES room_types(room_type_id),
  CONSTRAINT ck_rooms_floor CHECK (floor_no > 0)
) COMMENT='客房信息表';

CREATE TABLE customers (
  customer_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '客户编号',
  customer_name VARCHAR(50) NOT NULL COMMENT '客户姓名',
  id_card VARCHAR(30) NOT NULL UNIQUE COMMENT '身份证号',
  phone VARCHAR(20) NOT NULL UNIQUE COMMENT '联系电话',
  member_level ENUM('普通','银卡','金卡','钻石') NOT NULL DEFAULT '普通' COMMENT '会员等级',
  points INT NOT NULL DEFAULT 0 COMMENT '消费积分',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建档时间',
  CONSTRAINT ck_customers_points CHECK (points >= 0)
) COMMENT='客户会员表';

CREATE TABLE checkin_orders (
  order_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '入住订单编号',
  order_no VARCHAR(40) NOT NULL UNIQUE COMMENT '订单号',
  customer_id INT NOT NULL COMMENT '客户编号',
  room_id INT NOT NULL COMMENT '客房编号',
  receptionist_id INT NOT NULL COMMENT '办理前台员工',
  checkin_time DATETIME NOT NULL COMMENT '入住时间',
  expected_checkout_time DATETIME NULL COMMENT '预计退房时间',
  checkout_time DATETIME NULL COMMENT '实际退房时间',
  room_price DECIMAL(10,2) NOT NULL COMMENT '成交房价',
  deposit_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '押金',
  room_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '房费',
  extra_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '其他消费',
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '总金额',
  order_status ENUM('入住中','已退房','已取消') NOT NULL DEFAULT '入住中' COMMENT '订单状态',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  CONSTRAINT fk_orders_room FOREIGN KEY (room_id) REFERENCES rooms(room_id),
  CONSTRAINT fk_orders_receptionist FOREIGN KEY (receptionist_id) REFERENCES employees(employee_id),
  CONSTRAINT ck_orders_amount CHECK (room_price >= 0 AND deposit_amount >= 0 AND room_fee >= 0 AND extra_fee >= 0 AND total_amount >= 0)
) COMMENT='入住与退房订单表';

CREATE TABLE consumption_items (
  item_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '消费明细编号',
  order_id INT NOT NULL COMMENT '订单编号',
  item_type ENUM('餐饮','小商品','洗衣服务','其他') NOT NULL COMMENT '消费类型',
  item_name VARCHAR(100) NOT NULL COMMENT '消费名称',
  quantity INT NOT NULL DEFAULT 1 COMMENT '数量',
  unit_price DECIMAL(10,2) NOT NULL COMMENT '单价',
  amount DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED COMMENT '金额',
  consumed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '消费时间',
  CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES checkin_orders(order_id),
  CONSTRAINT ck_items_quantity CHECK (quantity > 0),
  CONSTRAINT ck_items_price CHECK (unit_price >= 0)
) COMMENT='订单消费明细表';

CREATE TABLE work_orders (
  work_order_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '工单编号',
  work_order_no VARCHAR(40) NOT NULL UNIQUE COMMENT '工单号',
  room_id INT NOT NULL COMMENT '关联客房',
  employee_id INT NOT NULL COMMENT '负责员工',
  order_type ENUM('保洁','维修') NOT NULL COMMENT '工单类型',
  order_status ENUM('待处理','处理中','已完成','已取消') NOT NULL DEFAULT '待处理' COMMENT '工单状态',
  description VARCHAR(300) NULL COMMENT '工单描述',
  performance_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '工单绩效金额',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  finished_at DATETIME NULL COMMENT '完成时间',
  CONSTRAINT fk_work_orders_room FOREIGN KEY (room_id) REFERENCES rooms(room_id),
  CONSTRAINT fk_work_orders_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
  CONSTRAINT ck_work_orders_perf CHECK (performance_amount >= 0)
) COMMENT='客房运维工单表';

CREATE TABLE schedules (
  schedule_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '排班编号',
  employee_id INT NOT NULL COMMENT '员工编号',
  work_date DATE NOT NULL COMMENT '工作日期',
  shift_type ENUM('早班','中班','晚班','休息') NOT NULL COMMENT '班次',
  start_time TIME NULL COMMENT '计划上班时间',
  end_time TIME NULL COMMENT '计划下班时间',
  CONSTRAINT uk_schedule_employee_date UNIQUE (employee_id, work_date),
  CONSTRAINT fk_schedules_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
) COMMENT='月度排班表';

CREATE TABLE attendance_records (
  attendance_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '考勤编号',
  employee_id INT NOT NULL COMMENT '员工编号',
  attendance_date DATE NOT NULL COMMENT '考勤日期',
  check_in_time DATETIME NULL COMMENT '上班打卡',
  check_out_time DATETIME NULL COMMENT '下班打卡',
  attendance_status ENUM('正常','迟到','早退','缺勤') NOT NULL DEFAULT '正常' COMMENT '考勤状态',
  CONSTRAINT uk_attendance_employee_date UNIQUE (employee_id, attendance_date),
  CONSTRAINT fk_attendance_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
) COMMENT='考勤打卡记录表';

CREATE TABLE leave_records (
  leave_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '请假编号',
  employee_id INT NOT NULL COMMENT '员工编号',
  leave_type ENUM('事假','病假','年假','调休') NOT NULL COMMENT '请假类型',
  start_time DATETIME NOT NULL COMMENT '开始时间',
  end_time DATETIME NOT NULL COMMENT '结束时间',
  approve_status ENUM('待审批','已通过','已驳回') NOT NULL DEFAULT '待审批' COMMENT '审批状态',
  reason VARCHAR(300) NULL COMMENT '请假原因',
  CONSTRAINT fk_leave_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
  CONSTRAINT ck_leave_time CHECK (end_time > start_time)
) COMMENT='请假登记表';

CREATE TABLE overtime_records (
  overtime_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '加班编号',
  employee_id INT NOT NULL COMMENT '员工编号',
  overtime_date DATE NOT NULL COMMENT '加班日期',
  hours DECIMAL(5,2) NOT NULL COMMENT '加班小时数',
  approve_status ENUM('待审批','已通过','已驳回') NOT NULL DEFAULT '待审批' COMMENT '审批状态',
  reason VARCHAR(300) NULL COMMENT '加班原因',
  CONSTRAINT fk_overtime_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
  CONSTRAINT ck_overtime_hours CHECK (hours > 0)
) COMMENT='加班登记表';

CREATE TABLE salary_records (
  salary_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '薪资编号',
  employee_id INT NOT NULL COMMENT '员工编号',
  salary_month CHAR(7) NOT NULL COMMENT '薪资月份，格式 YYYY-MM',
  base_salary DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '基本工资',
  attendance_deduction DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '考勤扣款',
  cleaning_bonus DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '保洁绩效',
  reception_bonus DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '前台提成',
  repair_bonus DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '维修绩效',
  overtime_pay DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '加班工资',
  other_deduction DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '其他扣款',
  actual_salary DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '实发工资',
  generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '生成时间',
  CONSTRAINT uk_salary_employee_month UNIQUE (employee_id, salary_month),
  CONSTRAINT fk_salary_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
  CONSTRAINT ck_salary_amount CHECK (
    base_salary >= 0 AND attendance_deduction >= 0 AND cleaning_bonus >= 0
    AND reception_bonus >= 0 AND repair_bonus >= 0 AND overtime_pay >= 0
    AND other_deduction >= 0 AND actual_salary >= 0
  )
) COMMENT='薪资核算表';

CREATE TABLE salary_payments (
  payment_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '发薪编号',
  salary_id INT NOT NULL UNIQUE COMMENT '薪资编号',
  paid_amount DECIMAL(10,2) NOT NULL COMMENT '发放金额',
  paid_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发放时间',
  payment_status ENUM('已发放','已撤销') NOT NULL DEFAULT '已发放' COMMENT '发放状态',
  operator_id INT NOT NULL COMMENT '操作员工',
  CONSTRAINT fk_payments_salary FOREIGN KEY (salary_id) REFERENCES salary_records(salary_id),
  CONSTRAINT fk_payments_operator FOREIGN KEY (operator_id) REFERENCES employees(employee_id),
  CONSTRAINT ck_payments_amount CHECK (paid_amount >= 0)
) COMMENT='薪资发放记录表';

CREATE TABLE operation_logs (
  log_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '日志编号',
  employee_id INT NULL COMMENT '相关员工',
  business_type VARCHAR(50) NOT NULL COMMENT '业务类型',
  business_id INT NULL COMMENT '业务编号',
  operation_content VARCHAR(500) NOT NULL COMMENT '操作内容',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  CONSTRAINT fk_logs_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
) COMMENT='系统操作日志表';
