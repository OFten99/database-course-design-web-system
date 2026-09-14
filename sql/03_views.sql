-- 酒店人事一体化综合管理系统：业务视图

USE hotel_hr_system;

DROP VIEW IF EXISTS v_monthly_room_revenue;
DROP VIEW IF EXISTS v_employee_monthly_attendance_summary;
DROP VIEW IF EXISTS v_current_occupied_rooms;
DROP VIEW IF EXISTS v_employee_performance_summary;

-- 1. 月度客房营收视图：按月份统计房费、其他消费和总收入
CREATE VIEW v_monthly_room_revenue AS
SELECT
  DATE_FORMAT(co.checkout_time, '%Y-%m') AS revenue_month,
  COUNT(co.order_id) AS checkout_order_count,
  SUM(co.room_fee) AS room_fee_amount,
  SUM(co.extra_fee) AS extra_fee_amount,
  SUM(co.total_amount) AS total_revenue
FROM checkin_orders co
WHERE co.order_status = '已退房'
  AND co.checkout_time IS NOT NULL
GROUP BY DATE_FORMAT(co.checkout_time, '%Y-%m');

-- 2. 员工月度考勤汇总视图：统计正常、迟到、早退、缺勤天数
CREATE VIEW v_employee_monthly_attendance_summary AS
SELECT
  e.employee_id,
  e.employee_no,
  e.employee_name,
  d.department_name,
  DATE_FORMAT(ar.attendance_date, '%Y-%m') AS attendance_month,
  COUNT(ar.attendance_id) AS attendance_days,
  SUM(CASE WHEN ar.attendance_status = '正常' THEN 1 ELSE 0 END) AS normal_days,
  SUM(CASE WHEN ar.attendance_status = '迟到' THEN 1 ELSE 0 END) AS late_days,
  SUM(CASE WHEN ar.attendance_status = '早退' THEN 1 ELSE 0 END) AS early_leave_days,
  SUM(CASE WHEN ar.attendance_status = '缺勤' THEN 1 ELSE 0 END) AS absent_days
FROM employees e
JOIN departments d ON e.department_id = d.department_id
LEFT JOIN attendance_records ar ON e.employee_id = ar.employee_id
GROUP BY
  e.employee_id, e.employee_no, e.employee_name, d.department_name,
  DATE_FORMAT(ar.attendance_date, '%Y-%m');

-- 3. 当前占用客房视图：展示正在入住的房间、客户和办理员工
CREATE VIEW v_current_occupied_rooms AS
SELECT
  r.room_id,
  r.room_no,
  r.floor_no,
  rt.type_name,
  rt.standard_price,
  c.customer_name,
  c.phone AS customer_phone,
  co.order_no,
  co.checkin_time,
  co.expected_checkout_time,
  e.employee_name AS receptionist_name
FROM rooms r
JOIN room_types rt ON r.room_type_id = rt.room_type_id
JOIN checkin_orders co ON r.room_id = co.room_id
JOIN customers c ON co.customer_id = c.customer_id
JOIN employees e ON co.receptionist_id = e.employee_id
WHERE r.room_status = '入住'
  AND co.order_status = '入住中';

-- 扩展视图：员工月度绩效汇总，用于薪资核算参考
CREATE VIEW v_employee_performance_summary AS
SELECT
  e.employee_id,
  e.employee_no,
  e.employee_name,
  ym.salary_month,
  COALESCE(clean.cleaning_bonus, 0) AS cleaning_bonus,
  COALESCE(repair.repair_bonus, 0) AS repair_bonus,
  COALESCE(front.reception_bonus, 0) AS reception_bonus
FROM employees e
JOIN (
  SELECT DATE_FORMAT(created_at, '%Y-%m') AS salary_month FROM work_orders
  UNION
  SELECT DATE_FORMAT(checkin_time, '%Y-%m') AS salary_month FROM checkin_orders
) ym
LEFT JOIN (
  SELECT employee_id, DATE_FORMAT(finished_at, '%Y-%m') AS salary_month, SUM(performance_amount) AS cleaning_bonus
  FROM work_orders
  WHERE order_type = '保洁' AND order_status = '已完成' AND finished_at IS NOT NULL
  GROUP BY employee_id, DATE_FORMAT(finished_at, '%Y-%m')
) clean ON e.employee_id = clean.employee_id AND ym.salary_month = clean.salary_month
LEFT JOIN (
  SELECT employee_id, DATE_FORMAT(finished_at, '%Y-%m') AS salary_month, SUM(performance_amount) AS repair_bonus
  FROM work_orders
  WHERE order_type = '维修' AND order_status = '已完成' AND finished_at IS NOT NULL
  GROUP BY employee_id, DATE_FORMAT(finished_at, '%Y-%m')
) repair ON e.employee_id = repair.employee_id AND ym.salary_month = repair.salary_month
LEFT JOIN (
  SELECT receptionist_id AS employee_id, DATE_FORMAT(checkin_time, '%Y-%m') AS salary_month, SUM(total_amount * 0.02) AS reception_bonus
  FROM checkin_orders
  WHERE order_status = '已退房'
  GROUP BY receptionist_id, DATE_FORMAT(checkin_time, '%Y-%m')
) front ON e.employee_id = front.employee_id AND ym.salary_month = front.salary_month;
