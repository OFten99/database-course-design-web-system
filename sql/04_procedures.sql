-- 酒店人事一体化综合管理系统：存储过程与事务

USE hotel_hr_system;

DROP PROCEDURE IF EXISTS sp_add_employee;
DROP PROCEDURE IF EXISTS sp_checkin;
DROP PROCEDURE IF EXISTS sp_checkout;
DROP PROCEDURE IF EXISTS sp_calculate_monthly_salary;
DROP PROCEDURE IF EXISTS sp_pay_salary;

DELIMITER $$

-- 1. 新增员工档案，同时创建系统登录账号
CREATE PROCEDURE sp_add_employee(
  IN p_employee_no VARCHAR(30),
  IN p_employee_name VARCHAR(50),
  IN p_gender VARCHAR(2),
  IN p_department_id INT,
  IN p_position_id INT,
  IN p_phone VARCHAR(20),
  IN p_id_card VARCHAR(30),
  IN p_hire_date DATE,
  IN p_base_salary DECIMAL(10,2),
  IN p_role_id INT,
  IN p_username VARCHAR(50),
  IN p_password_hash VARCHAR(128)
)
BEGIN
  DECLARE v_employee_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  INSERT INTO employees (
    employee_no, employee_name, gender, department_id, position_id,
    phone, id_card, hire_date, base_salary
  ) VALUES (
    p_employee_no, p_employee_name, p_gender, p_department_id, p_position_id,
    p_phone, p_id_card, p_hire_date, p_base_salary
  );

  SET v_employee_id = LAST_INSERT_ID();

  INSERT INTO user_accounts (employee_id, role_id, username, password_hash)
  VALUES (v_employee_id, p_role_id, p_username, p_password_hash);

  INSERT INTO operation_logs (employee_id, business_type, business_id, operation_content)
  VALUES (v_employee_id, '员工建档', v_employee_id, CONCAT('新增员工档案：', p_employee_name));

  COMMIT;
END$$

-- 2. 办理入住：校验客房状态，写入订单，更新房态
CREATE PROCEDURE sp_checkin(
  IN p_order_no VARCHAR(40),
  IN p_customer_id INT,
  IN p_room_id INT,
  IN p_receptionist_id INT,
  IN p_expected_checkout_time DATETIME,
  IN p_room_price DECIMAL(10,2),
  IN p_deposit_amount DECIMAL(10,2)
)
BEGIN
  DECLARE v_room_status VARCHAR(20);
  DECLARE v_order_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT room_status INTO v_room_status
  FROM rooms
  WHERE room_id = p_room_id
  FOR UPDATE;

  IF v_room_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '客房不存在';
  END IF;

  IF v_room_status <> '空闲' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '客房当前不可入住';
  END IF;

  INSERT INTO checkin_orders (
    order_no, customer_id, room_id, receptionist_id, checkin_time,
    expected_checkout_time, room_price, deposit_amount, order_status
  ) VALUES (
    p_order_no, p_customer_id, p_room_id, p_receptionist_id, NOW(),
    p_expected_checkout_time, p_room_price, p_deposit_amount, '入住中'
  );

  SET v_order_id = LAST_INSERT_ID();

  UPDATE rooms
  SET room_status = '入住'
  WHERE room_id = p_room_id;

  INSERT INTO operation_logs (employee_id, business_type, business_id, operation_content)
  VALUES (p_receptionist_id, '办理入住', v_order_id, CONCAT('办理入住订单：', p_order_no));

  COMMIT;
END$$

-- 3. 退房结算：计算房费、消费明细、总金额，触发器自动把客房改为待打扫
CREATE PROCEDURE sp_checkout(
  IN p_order_id INT,
  IN p_operator_id INT
)
BEGIN
  DECLARE v_room_id INT;
  DECLARE v_checkin_time DATETIME;
  DECLARE v_room_price DECIMAL(10,2);
  DECLARE v_days INT;
  DECLARE v_room_fee DECIMAL(10,2);
  DECLARE v_extra_fee DECIMAL(10,2);
  DECLARE v_total_amount DECIMAL(10,2);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT room_id, checkin_time, room_price
  INTO v_room_id, v_checkin_time, v_room_price
  FROM checkin_orders
  WHERE order_id = p_order_id AND order_status = '入住中'
  FOR UPDATE;

  IF v_room_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '订单不存在或不是入住中状态';
  END IF;

  SET v_days = GREATEST(1, DATEDIFF(CURDATE(), DATE(v_checkin_time)) + 1);
  SET v_room_fee = v_days * v_room_price;

  SELECT COALESCE(SUM(amount), 0)
  INTO v_extra_fee
  FROM consumption_items
  WHERE order_id = p_order_id;

  SET v_total_amount = v_room_fee + v_extra_fee;

  UPDATE checkin_orders
  SET checkout_time = NOW(),
      room_fee = v_room_fee,
      extra_fee = v_extra_fee,
      total_amount = v_total_amount,
      order_status = '已退房'
  WHERE order_id = p_order_id;

  UPDATE customers c
  JOIN checkin_orders co ON c.customer_id = co.customer_id
  SET c.points = c.points + FLOOR(v_total_amount)
  WHERE co.order_id = p_order_id;

  INSERT INTO operation_logs (employee_id, business_type, business_id, operation_content)
  VALUES (p_operator_id, '退房结算', p_order_id, CONCAT('退房结算金额：', v_total_amount));

  COMMIT;
END$$

-- 4. 批量计算员工月度薪资：整合考勤扣款、保洁绩效、前台提成、维修绩效、加班工资
CREATE PROCEDURE sp_calculate_monthly_salary(
  IN p_salary_month CHAR(7)
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  INSERT INTO salary_records (
    employee_id, salary_month, base_salary, attendance_deduction,
    cleaning_bonus, reception_bonus, repair_bonus, overtime_pay,
    other_deduction, actual_salary
  )
  SELECT
    e.employee_id,
    p_salary_month,
    e.base_salary,
    COALESCE(att.deduction, 0) AS attendance_deduction,
    COALESCE(clean.cleaning_bonus, 0) AS cleaning_bonus,
    COALESCE(front.reception_bonus, 0) AS reception_bonus,
    COALESCE(repair.repair_bonus, 0) AS repair_bonus,
    COALESCE(ot.overtime_pay, 0) AS overtime_pay,
    0 AS other_deduction,
    GREATEST(
      0,
      e.base_salary
      - COALESCE(att.deduction, 0)
      + COALESCE(clean.cleaning_bonus, 0)
      + COALESCE(front.reception_bonus, 0)
      + COALESCE(repair.repair_bonus, 0)
      + COALESCE(ot.overtime_pay, 0)
    ) AS actual_salary
  FROM employees e
  LEFT JOIN (
    SELECT
      employee_id,
      DATE_FORMAT(attendance_date, '%Y-%m') AS salary_month,
      SUM(CASE
        WHEN attendance_status = '缺勤' THEN 100
        WHEN attendance_status IN ('迟到','早退') THEN 20
        ELSE 0
      END) AS deduction
    FROM attendance_records
    GROUP BY employee_id, DATE_FORMAT(attendance_date, '%Y-%m')
  ) att ON e.employee_id = att.employee_id AND att.salary_month = p_salary_month
  LEFT JOIN (
    SELECT employee_id, DATE_FORMAT(finished_at, '%Y-%m') AS salary_month, SUM(performance_amount) AS cleaning_bonus
    FROM work_orders
    WHERE order_type = '保洁' AND order_status = '已完成' AND finished_at IS NOT NULL
    GROUP BY employee_id, DATE_FORMAT(finished_at, '%Y-%m')
  ) clean ON e.employee_id = clean.employee_id AND clean.salary_month = p_salary_month
  LEFT JOIN (
    SELECT employee_id, DATE_FORMAT(finished_at, '%Y-%m') AS salary_month, SUM(performance_amount) AS repair_bonus
    FROM work_orders
    WHERE order_type = '维修' AND order_status = '已完成' AND finished_at IS NOT NULL
    GROUP BY employee_id, DATE_FORMAT(finished_at, '%Y-%m')
  ) repair ON e.employee_id = repair.employee_id AND repair.salary_month = p_salary_month
  LEFT JOIN (
    SELECT receptionist_id AS employee_id, DATE_FORMAT(checkin_time, '%Y-%m') AS salary_month, SUM(total_amount * 0.02) AS reception_bonus
    FROM checkin_orders
    WHERE order_status = '已退房'
    GROUP BY receptionist_id, DATE_FORMAT(checkin_time, '%Y-%m')
  ) front ON e.employee_id = front.employee_id AND front.salary_month = p_salary_month
  LEFT JOIN (
    SELECT employee_id, DATE_FORMAT(overtime_date, '%Y-%m') AS salary_month, SUM(hours * 30) AS overtime_pay
    FROM overtime_records
    WHERE approve_status = '已通过'
    GROUP BY employee_id, DATE_FORMAT(overtime_date, '%Y-%m')
  ) ot ON e.employee_id = ot.employee_id AND ot.salary_month = p_salary_month
  WHERE e.employment_status = '在职'
  ON DUPLICATE KEY UPDATE
    base_salary = VALUES(base_salary),
    attendance_deduction = VALUES(attendance_deduction),
    cleaning_bonus = VALUES(cleaning_bonus),
    reception_bonus = VALUES(reception_bonus),
    repair_bonus = VALUES(repair_bonus),
    overtime_pay = VALUES(overtime_pay),
    other_deduction = VALUES(other_deduction),
    actual_salary = VALUES(actual_salary),
    generated_at = CURRENT_TIMESTAMP;

  INSERT INTO operation_logs (employee_id, business_type, business_id, operation_content)
  VALUES (NULL, '薪资核算', NULL, CONCAT('批量生成月度薪资：', p_salary_month));

  COMMIT;
END$$

-- 5. 发薪事务：防止重复发放
CREATE PROCEDURE sp_pay_salary(
  IN p_salary_id INT,
  IN p_operator_id INT
)
BEGIN
  DECLARE v_actual_salary DECIMAL(10,2);
  DECLARE v_existing_count INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT actual_salary INTO v_actual_salary
  FROM salary_records
  WHERE salary_id = p_salary_id
  FOR UPDATE;

  IF v_actual_salary IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '薪资记录不存在';
  END IF;

  SELECT COUNT(*) INTO v_existing_count
  FROM salary_payments
  WHERE salary_id = p_salary_id AND payment_status = '已发放';

  IF v_existing_count > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该薪资记录已经发放，不能重复发薪';
  END IF;

  INSERT INTO salary_payments (salary_id, paid_amount, operator_id)
  VALUES (p_salary_id, v_actual_salary, p_operator_id);

  INSERT INTO operation_logs (employee_id, business_type, business_id, operation_content)
  VALUES (p_operator_id, '薪资发放', p_salary_id, CONCAT('发放薪资金额：', v_actual_salary));

  COMMIT;
END$$

DELIMITER ;
