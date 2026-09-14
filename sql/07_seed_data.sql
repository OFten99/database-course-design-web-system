-- 酒店人事一体化综合管理系统：测试数据
-- 建议执行顺序：01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07

USE hotel_hr_system;

-- 一、部门、角色、岗位
INSERT INTO departments (department_name, description) VALUES
('前厅部', '负责前台接待、入住退房和客户服务'),
('客房部', '负责客房保洁、客房服务和物品管理'),
('财务部', '负责薪资核算、报表统计和财务管理'),
('安保部', '负责酒店安全、巡检和设备维护');

INSERT INTO roles (role_code, role_name, description) VALUES
('FRONT_DESK', '前台', '办理入住、退房和客户管理'),
('HR', '人事', '管理员工档案、考勤和排班'),
('FINANCE', '财务', '核算薪资、查看营收和发薪'),
('MANAGER', '经理', '查看全部业务数据和统计报表');

INSERT INTO positions (department_id, position_name, base_salary, performance_rate) VALUES
(1, '前台接待', 4200.00, 0.02),
(2, '客房保洁员', 3600.00, 15.00),
(2, '客房主管', 5200.00, 20.00),
(3, '财务专员', 5000.00, 0.00),
(4, '维修员', 4300.00, 30.00),
(1, '值班经理', 7000.00, 0.00);

-- 二、员工和账号
CALL sp_add_employee('E2026001', '张敏', '女', 1, 1, '13800000001', '330101199801010011', '2024-03-01', 4200.00, 1, 'front01', SHA2('123456', 256));
CALL sp_add_employee('E2026002', '李强', '男', 2, 2, '13800000002', '330101199702020022', '2023-06-15', 3600.00, 2, 'room01', SHA2('123456', 256));
CALL sp_add_employee('E2026003', '王芳', '女', 2, 3, '13800000003', '330101199603030033', '2022-04-20', 5200.00, 2, 'room_mgr', SHA2('123456', 256));
CALL sp_add_employee('E2026004', '赵磊', '男', 3, 4, '13800000004', '330101199504040044', '2021-09-10', 5000.00, 3, 'finance01', SHA2('123456', 256));
CALL sp_add_employee('E2026005', '陈安', '男', 4, 5, '13800000005', '330101199405050055', '2023-02-08', 4300.00, 2, 'repair01', SHA2('123456', 256));
CALL sp_add_employee('E2026006', '刘经理', '女', 1, 6, '13800000006', '330101199306060066', '2020-01-01', 7000.00, 4, 'manager01', SHA2('123456', 256));

UPDATE departments SET manager_employee_id = 6 WHERE department_name = '前厅部';
UPDATE departments SET manager_employee_id = 3 WHERE department_name = '客房部';
UPDATE departments SET manager_employee_id = 4 WHERE department_name = '财务部';
UPDATE departments SET manager_employee_id = 5 WHERE department_name = '安保部';

-- 三、房型、客房、客户
INSERT INTO room_types (type_name, standard_price, max_guests, facilities) VALUES
('标准单人间', 198.00, 1, '单人床、独立卫浴、电视、无线网络'),
('商务大床房', 298.00, 2, '大床、办公桌、独立卫浴、无线网络'),
('豪华双床房', 368.00, 2, '双床、沙发、独立卫浴、迷你吧'),
('行政套房', 688.00, 3, '客厅、卧室、浴缸、迷你吧、办公区');

INSERT INTO rooms (room_no, floor_no, room_type_id, room_status, remark) VALUES
('101', 1, 1, '空闲', '靠近电梯'),
('102', 1, 1, '空闲', NULL),
('201', 2, 2, '空闲', '朝南'),
('202', 2, 2, '空闲', NULL),
('301', 3, 3, '空闲', '景观较好'),
('302', 3, 3, '维修', '空调检修'),
('401', 4, 4, '空闲', '行政楼层'),
('402', 4, 4, '空闲', NULL);

INSERT INTO customers (customer_name, id_card, phone, member_level, points) VALUES
('周明', '310101199001010011', '13900000001', '银卡', 1200),
('吴倩', '310101199202020022', '13900000002', '普通', 100),
('郑凯', '310101198803030033', '13900000003', '金卡', 3600),
('孙丽', '310101199404040044', '13900000004', '钻石', 8800);

-- 四、入住、消费、退房业务演示
CALL sp_checkin('ORD202607130001', 1, 1, 1, DATE_ADD(NOW(), INTERVAL 1 DAY), 198.00, 300.00);
INSERT INTO consumption_items (order_id, item_type, item_name, quantity, unit_price)
VALUES
(1, '餐饮', '早餐', 2, 38.00),
(1, '洗衣服务', '衬衫清洗', 1, 25.00);
CALL sp_checkout(1, 1);

CALL sp_checkin('ORD202607130002', 2, 3, 1, DATE_ADD(NOW(), INTERVAL 2 DAY), 298.00, 500.00);
INSERT INTO consumption_items (order_id, item_type, item_name, quantity, unit_price)
VALUES
(2, '小商品', '矿泉水', 4, 5.00),
(2, '餐饮', '晚餐套餐', 1, 88.00);

-- 五、工单业务演示
INSERT INTO work_orders (work_order_no, room_id, employee_id, order_type, order_status, description, performance_amount)
VALUES
('WO202607130001', 1, 2, '保洁', '待处理', '退房后客房保洁', 30.00),
('WO202607130002', 6, 5, '维修', '待处理', '302 房空调检修', 60.00);

UPDATE work_orders
SET order_status = '已完成', finished_at = NOW()
WHERE work_order_no = 'WO202607130001';

UPDATE work_orders
SET order_status = '已完成', finished_at = NOW()
WHERE work_order_no = 'WO202607130002';

-- 六、考勤、请假、加班
INSERT INTO schedules (employee_id, work_date, shift_type, start_time, end_time) VALUES
(1, '2026-07-13', '早班', '08:00:00', '16:00:00'),
(2, '2026-07-13', '早班', '08:00:00', '16:00:00'),
(4, '2026-07-13', '中班', '12:00:00', '20:00:00'),
(5, '2026-07-13', '早班', '08:00:00', '16:00:00');

INSERT INTO attendance_records (employee_id, attendance_date, check_in_time, check_out_time, attendance_status) VALUES
(1, '2026-07-13', '2026-07-13 07:55:00', '2026-07-13 16:02:00', '正常'),
(2, '2026-07-13', '2026-07-13 08:12:00', '2026-07-13 16:05:00', '迟到'),
(4, '2026-07-13', '2026-07-13 11:58:00', '2026-07-13 20:00:00', '正常'),
(5, '2026-07-13', '2026-07-13 08:00:00', '2026-07-13 15:30:00', '早退');

INSERT INTO leave_records (employee_id, leave_type, start_time, end_time, approve_status, reason)
VALUES (3, '年假', '2026-07-14 08:00:00', '2026-07-14 17:00:00', '已通过', '个人年假');

INSERT INTO overtime_records (employee_id, overtime_date, hours, approve_status, reason)
VALUES
(1, '2026-07-13', 2.00, '已通过', '晚间客流高峰支援'),
(5, '2026-07-13', 1.50, '已通过', '设备维修加班');

-- 七、薪资核算和发薪演示
CALL sp_calculate_monthly_salary('2026-07');

SET @salary_id = (
  SELECT salary_id
  FROM salary_records
  WHERE employee_id = 1 AND salary_month = '2026-07'
  LIMIT 1
);
CALL sp_pay_salary(@salary_id, 4);

-- 八、离职触发器演示：锁定离职员工账号
UPDATE employees
SET employment_status = '离职', leave_date = '2026-07-13'
WHERE employee_no = 'E2026006';

-- 九、常用检查语句
SELECT * FROM v_current_occupied_rooms;
SELECT * FROM v_monthly_room_revenue;
SELECT * FROM v_employee_monthly_attendance_summary;
SELECT * FROM salary_records ORDER BY salary_month, employee_id;
SELECT * FROM operation_logs ORDER BY created_at DESC;
