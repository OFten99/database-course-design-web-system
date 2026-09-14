-- 酒店人事一体化综合管理系统：索引、复杂查询与统计查询

USE hotel_hr_system;

-- 一、常用字段索引
CREATE INDEX idx_rooms_status ON rooms(room_status);
CREATE INDEX idx_rooms_floor_type ON rooms(floor_no, room_type_id);
CREATE INDEX idx_orders_customer ON checkin_orders(customer_id);
CREATE INDEX idx_orders_room_status ON checkin_orders(room_id, order_status);
CREATE INDEX idx_orders_checkin_month ON checkin_orders(checkin_time);
CREATE INDEX idx_orders_checkout_month ON checkin_orders(checkout_time);
CREATE INDEX idx_work_orders_employee_type ON work_orders(employee_id, order_type, order_status);
CREATE INDEX idx_attendance_employee_date ON attendance_records(employee_id, attendance_date);
CREATE INDEX idx_salary_month ON salary_records(salary_month);
CREATE INDEX idx_logs_created_at ON operation_logs(created_at);

-- 二、多表联查：查询当前入住订单明细
SELECT
  co.order_no,
  c.customer_name,
  c.phone,
  r.room_no,
  rt.type_name,
  co.checkin_time,
  co.deposit_amount,
  e.employee_name AS receptionist_name
FROM checkin_orders co
JOIN customers c ON co.customer_id = c.customer_id
JOIN rooms r ON co.room_id = r.room_id
JOIN room_types rt ON r.room_type_id = rt.room_type_id
JOIN employees e ON co.receptionist_id = e.employee_id
WHERE co.order_status = '入住中'
ORDER BY co.checkin_time DESC;

-- 三、分组统计：按部门统计员工人数和平均基本工资
SELECT
  d.department_name,
  COUNT(e.employee_id) AS employee_count,
  ROUND(AVG(e.base_salary), 2) AS avg_base_salary
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name
ORDER BY employee_count DESC;

-- 四、子查询：查询高于本部门平均工资的员工
SELECT
  e.employee_no,
  e.employee_name,
  d.department_name,
  e.base_salary
FROM employees e
JOIN departments d ON e.department_id = d.department_id
WHERE e.base_salary > (
  SELECT AVG(e2.base_salary)
  FROM employees e2
  WHERE e2.department_id = e.department_id
)
ORDER BY d.department_name, e.base_salary DESC;

-- 五、绩效统计：按月统计保洁、维修、前台提成
SELECT
  employee_no,
  employee_name,
  salary_month,
  cleaning_bonus,
  repair_bonus,
  reception_bonus,
  cleaning_bonus + repair_bonus + reception_bonus AS total_performance
FROM v_employee_performance_summary
ORDER BY salary_month DESC, total_performance DESC;

-- 六、营收统计：按房型统计月度营收
SELECT
  DATE_FORMAT(co.checkout_time, '%Y-%m') AS revenue_month,
  rt.type_name,
  COUNT(co.order_id) AS order_count,
  SUM(co.room_fee) AS room_fee,
  SUM(co.extra_fee) AS extra_fee,
  SUM(co.total_amount) AS total_revenue
FROM checkin_orders co
JOIN rooms r ON co.room_id = r.room_id
JOIN room_types rt ON r.room_type_id = rt.room_type_id
WHERE co.order_status = '已退房'
GROUP BY DATE_FORMAT(co.checkout_time, '%Y-%m'), rt.type_name
ORDER BY revenue_month DESC, total_revenue DESC;

-- 七、发薪记录查询
SELECT
  sr.salary_month,
  e.employee_no,
  e.employee_name,
  d.department_name,
  sr.base_salary,
  sr.cleaning_bonus,
  sr.reception_bonus,
  sr.repair_bonus,
  sr.overtime_pay,
  sr.attendance_deduction,
  sr.actual_salary,
  sp.payment_status,
  sp.paid_at
FROM salary_records sr
JOIN employees e ON sr.employee_id = e.employee_id
JOIN departments d ON e.department_id = d.department_id
LEFT JOIN salary_payments sp ON sr.salary_id = sp.salary_id
ORDER BY sr.salary_month DESC, e.employee_no;
