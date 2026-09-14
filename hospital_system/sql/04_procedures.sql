-- 医院门诊管理系统：存储过程与事务
-- 覆盖：新增用户/医生、挂号、退号、开具处方、收费、退费

USE hospital_outpatient;

DROP PROCEDURE IF EXISTS sp_add_user;
DROP PROCEDURE IF EXISTS sp_add_doctor;
DROP PROCEDURE IF EXISTS sp_register;
DROP PROCEDURE IF EXISTS sp_cancel_registration;
DROP PROCEDURE IF EXISTS sp_issue_prescription;
DROP PROCEDURE IF EXISTS sp_charge;
DROP PROCEDURE IF EXISTS sp_refund;

DELIMITER $$

-- 1. 新增系统用户（挂号员/收费员/管理员等非医生角色）
CREATE PROCEDURE sp_add_user(
  IN p_user_no VARCHAR(30),
  IN p_user_name VARCHAR(50),
  IN p_gender VARCHAR(2),
  IN p_department_id INT,
  IN p_role_id INT,
  IN p_phone VARCHAR(20),
  IN p_username VARCHAR(50),
  IN p_password_hash VARCHAR(128)
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
  INSERT INTO users (user_no, user_name, gender, department_id, role_id, phone, username, password_hash)
  VALUES (p_user_no, p_user_name, p_gender, p_department_id, p_role_id, p_phone, p_username, p_password_hash);
  COMMIT;
END$$

-- 2. 新增医生：一次创建系统用户和医生档案
CREATE PROCEDURE sp_add_doctor(
  IN p_user_no VARCHAR(30),
  IN p_doctor_name VARCHAR(50),
  IN p_gender VARCHAR(2),
  IN p_department_id INT,
  IN p_phone VARCHAR(20),
  IN p_username VARCHAR(50),
  IN p_password_hash VARCHAR(128),
  IN p_title VARCHAR(30),
  IN p_specialty VARCHAR(100),
  IN p_consultation_fee DECIMAL(10,2),
  IN p_max_daily INT
)
BEGIN
  DECLARE v_role_id INT;
  DECLARE v_user_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT role_id INTO v_role_id FROM roles WHERE role_code = 'DOCTOR';
  IF v_role_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '缺少 DOCTOR 角色定义';
  END IF;

  INSERT INTO users (user_no, user_name, gender, department_id, role_id, phone, username, password_hash)
  VALUES (p_user_no, p_doctor_name, p_gender, p_department_id, v_role_id, p_phone, p_username, p_password_hash);
  SET v_user_id = LAST_INSERT_ID();

  INSERT INTO doctors (user_id, doctor_no, title, specialty, consultation_fee, max_daily_registrations)
  VALUES (v_user_id, p_user_no, p_title, p_specialty, p_consultation_fee, p_max_daily);

  COMMIT;
END$$

-- 3. 挂号：校验排班号源，生成挂号记录并扣减号源，同时收取挂号费
CREATE PROCEDURE sp_register(
  IN p_reg_no VARCHAR(40),
  IN p_patient_id INT,
  IN p_doctor_id INT,
  IN p_schedule_id INT,
  IN p_reg_type VARCHAR(10),
  IN p_operator_id INT,
  IN p_pay_method VARCHAR(10)
)
BEGIN
  DECLARE v_department_id INT;
  DECLARE v_fee DECIMAL(10,2);
  DECLARE v_registered INT;
  DECLARE v_max INT;
  DECLARE v_status VARCHAR(10);
  DECLARE v_doctor_id INT;
  DECLARE v_queue INT;
  DECLARE v_registration_id INT;
  DECLARE v_payment_no VARCHAR(40);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT max_registrations, registered_count, schedule_status, doctor_id
  INTO v_max, v_registered, v_status, v_doctor_id
  FROM doctor_schedules
  WHERE schedule_id = p_schedule_id
  FOR UPDATE;

  IF v_max IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '排班不存在';
  END IF;
  IF v_status = '停诊' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该排班已停诊，不能挂号';
  END IF;
  IF v_registered >= v_max THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '号源已满，无法挂号';
  END IF;

  SELECT consultation_fee INTO v_fee FROM doctors WHERE doctor_id = p_doctor_id;
  SELECT department_id INTO v_department_id FROM users u JOIN doctors doc ON u.user_id = doc.user_id WHERE doc.doctor_id = p_doctor_id;

  SET v_queue = v_registered + 1;

  INSERT INTO registrations (
    reg_no, patient_id, doctor_id, department_id, reg_date,
    reg_type, reg_fee, queue_no, visit_status, operator_id
  ) VALUES (
    p_reg_no, p_patient_id, p_doctor_id, v_department_id, CURDATE(),
    p_reg_type, v_fee, v_queue, '待就诊', p_operator_id
  );
  SET v_registration_id = LAST_INSERT_ID();

  UPDATE doctor_schedules
  SET registered_count = registered_count + 1
  WHERE schedule_id = p_schedule_id;

  SET v_payment_no = CONCAT('PAY', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), LPAD(v_registration_id, 4, '0'));
  INSERT INTO payments (
    payment_no, patient_id, registration_id, payment_type,
    pay_amount, pay_method, pay_status, operator_id
  ) VALUES (
    v_payment_no, p_patient_id, v_registration_id, '挂号费',
    v_fee, p_pay_method, '已收费', p_operator_id
  );

  COMMIT;
END$$

-- 4. 退号：校验待就诊状态，恢复号源并退回挂号费
CREATE PROCEDURE sp_cancel_registration(
  IN p_registration_id INT,
  IN p_operator_id INT,
  IN p_refund_reason VARCHAR(200)
)
BEGIN
  DECLARE v_doctor_id INT;
  DECLARE v_status VARCHAR(10);
  DECLARE v_patient_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT doctor_id, visit_status, patient_id
  INTO v_doctor_id, v_status, v_patient_id
  FROM registrations
  WHERE registration_id = p_registration_id
  FOR UPDATE;

  IF v_doctor_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '挂号记录不存在';
  END IF;
  IF v_status <> '待就诊' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '仅待就诊状态的挂号可以退号';
  END IF;

  UPDATE registrations
  SET visit_status = '已退号'
  WHERE registration_id = p_registration_id;

  UPDATE doctor_schedules s
  JOIN registrations r ON s.doctor_id = r.doctor_id
     AND s.work_date = r.reg_date
  SET s.registered_count = GREATEST(s.registered_count - 1, 0)
  WHERE r.registration_id = p_registration_id;

  UPDATE payments
  SET pay_status = '已退费',
      refund_time = NOW(),
      refund_operator_id = p_operator_id,
      refund_reason = p_refund_reason
  WHERE registration_id = p_registration_id
    AND payment_type = '挂号费'
    AND pay_status = '已收费';

  INSERT INTO operation_logs (user_id, business_type, business_id, operation_content)
  VALUES (p_operator_id, '退号', p_registration_id, CONCAT('退号，原因：', COALESCE(p_refund_reason, '无')));

  COMMIT;
END$$

-- 5. 开具处方：创建处方头并解析 JSON 明细，校验库存、计算总金额
CREATE PROCEDURE sp_issue_prescription(
  IN p_prescription_no VARCHAR(40),
  IN p_patient_id INT,
  IN p_doctor_id INT,
  IN p_registration_id INT,
  IN p_items_json JSON
)
BEGIN
  DECLARE v_prescription_id INT;
  DECLARE v_total DECIMAL(10,2);
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_medicine_id INT;
  DECLARE v_quantity INT;
  DECLARE v_stock INT;
  DECLARE cur_items CURSOR FOR
    SELECT jt.medicine_id, jt.quantity
    FROM JSON_TABLE(p_items_json, '$[*]' COLUMNS (
      medicine_id INT PATH '$.medicine_id',
      quantity INT PATH '$.quantity'
    )) jt;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  INSERT INTO prescriptions (prescription_no, patient_id, doctor_id, registration_id, prescribe_date, prescription_status)
  VALUES (p_prescription_no, p_patient_id, p_doctor_id, p_registration_id, CURDATE(), '待收费');
  SET v_prescription_id = LAST_INSERT_ID();

  -- 第一步：逐条校验药品存在且库存充足
  OPEN cur_items;
  item_loop: LOOP
    FETCH cur_items INTO v_medicine_id, v_quantity;
    IF v_done = 1 THEN
      LEAVE item_loop;
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines
    WHERE medicine_id = v_medicine_id
    FOR UPDATE;

    IF v_stock IS NULL THEN
      SET @err_msg = CONCAT('药品不存在：', v_medicine_id);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @err_msg;
    END IF;
    IF v_stock < v_quantity THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '药品库存不足，请修改数量或更换药品';
    END IF;
  END LOOP;
  CLOSE cur_items;

  -- 第二步：批量写入处方明细
  INSERT INTO prescription_items (prescription_id, medicine_id, medicine_name, quantity, unit_price, dosage)
  SELECT
    v_prescription_id,
    jt.medicine_id,
    m.medicine_name,
    jt.quantity,
    m.unit_price,
    jt.dosage
  FROM JSON_TABLE(p_items_json, '$[*]' COLUMNS (
    medicine_id INT PATH '$.medicine_id',
    quantity INT PATH '$.quantity',
    dosage VARCHAR(200) PATH '$.dosage'
  )) jt
  JOIN medicines m ON jt.medicine_id = m.medicine_id;

  SELECT SUM(amount) INTO v_total FROM prescription_items WHERE prescription_id = v_prescription_id;
  UPDATE prescriptions SET total_amount = COALESCE(v_total, 0) WHERE prescription_id = v_prescription_id;

  UPDATE registrations
  SET visit_status = '已就诊'
  WHERE registration_id = p_registration_id AND visit_status IN ('待就诊','就诊中');

  INSERT INTO operation_logs (user_id, business_type, business_id, operation_content)
  VALUES (p_doctor_id, '开具处方', v_prescription_id, CONCAT('开具处方：', p_prescription_no, '，金额：', COALESCE(v_total, 0)));

  COMMIT;
END$$

-- 6. 收费：校验处方待收费，生成收费记录并扣减药品库存
CREATE PROCEDURE sp_charge(
  IN p_prescription_id INT,
  IN p_operator_id INT,
  IN p_payment_no VARCHAR(40),
  IN p_pay_method VARCHAR(10)
)
BEGIN
  DECLARE v_patient_id INT;
  DECLARE v_status VARCHAR(10);
  DECLARE v_total DECIMAL(10,2);
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_medicine_id INT;
  DECLARE v_quantity INT;
  DECLARE cur_items CURSOR FOR
    SELECT medicine_id, quantity FROM prescription_items WHERE prescription_id = p_prescription_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT patient_id, prescription_status, total_amount
  INTO v_patient_id, v_status, v_total
  FROM prescriptions
  WHERE prescription_id = p_prescription_id
  FOR UPDATE;

  IF v_patient_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '处方不存在';
  END IF;
  IF v_status <> '待收费' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '仅待收费状态的处方可以收费';
  END IF;

  INSERT INTO payments (
    payment_no, patient_id, prescription_id, payment_type,
    pay_amount, pay_method, pay_status, operator_id
  ) VALUES (
    p_payment_no, v_patient_id, p_prescription_id, '药品费',
    v_total, p_pay_method, '已收费', p_operator_id
  );

  UPDATE prescriptions
  SET prescription_status = '已收费'
  WHERE prescription_id = p_prescription_id;

  OPEN cur_items;
  stock_loop: LOOP
    FETCH cur_items INTO v_medicine_id, v_quantity;
    IF v_done = 1 THEN
      LEAVE stock_loop;
    END IF;
    UPDATE medicines
    SET stock_quantity = GREATEST(stock_quantity - v_quantity, 0)
    WHERE medicine_id = v_medicine_id;
  END LOOP;
  CLOSE cur_items;

  COMMIT;
END$$

-- 7. 退费：校验处方已收费，退回费用并恢复药品库存
CREATE PROCEDURE sp_refund(
  IN p_prescription_id INT,
  IN p_operator_id INT,
  IN p_refund_reason VARCHAR(200)
)
BEGIN
  DECLARE v_patient_id INT;
  DECLARE v_status VARCHAR(10);
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_medicine_id INT;
  DECLARE v_quantity INT;
  DECLARE cur_items CURSOR FOR
    SELECT medicine_id, quantity FROM prescription_items WHERE prescription_id = p_prescription_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT patient_id, prescription_status
  INTO v_patient_id, v_status
  FROM prescriptions
  WHERE prescription_id = p_prescription_id
  FOR UPDATE;

  IF v_patient_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '处方不存在';
  END IF;
  IF v_status <> '已收费' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '仅已收费状态的处方可以退费';
  END IF;

  UPDATE payments
  SET pay_status = '已退费',
      refund_time = NOW(),
      refund_operator_id = p_operator_id,
      refund_reason = p_refund_reason
  WHERE prescription_id = p_prescription_id
    AND payment_type = '药品费'
    AND pay_status = '已收费';

  UPDATE prescriptions
  SET prescription_status = '已退费'
  WHERE prescription_id = p_prescription_id;

  OPEN cur_items;
  refund_loop: LOOP
    FETCH cur_items INTO v_medicine_id, v_quantity;
    IF v_done = 1 THEN
      LEAVE refund_loop;
    END IF;
    UPDATE medicines
    SET stock_quantity = stock_quantity + v_quantity
    WHERE medicine_id = v_medicine_id;
  END LOOP;
  CLOSE cur_items;

  INSERT INTO operation_logs (user_id, business_type, business_id, operation_content)
  VALUES (p_operator_id, '退费', p_prescription_id, CONCAT('处方退费，原因：', COALESCE(p_refund_reason, '无')));

  COMMIT;
END$$

DELIMITER ;
