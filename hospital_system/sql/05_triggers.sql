-- 医院门诊管理系统：触发器
-- 1. 挂号后自动写操作日志
-- 2. 收费后自动写操作日志
-- 3. 新增患者档案自动写日志
-- 4. 有号源被占用的排班禁止直接停诊（需先处理已挂号患者）

USE hospital_outpatient;

DROP TRIGGER IF EXISTS trg_registration_log;
DROP TRIGGER IF EXISTS trg_payment_log;
DROP TRIGGER IF EXISTS trg_patient_log;
DROP TRIGGER IF EXISTS trg_schedule_guard;

DELIMITER $$

-- 1. 新增挂号后自动写日志
CREATE TRIGGER trg_registration_log
AFTER INSERT ON registrations
FOR EACH ROW
BEGIN
  INSERT INTO operation_logs (user_id, business_type, business_id, operation_content)
  VALUES (
    NEW.operator_id,
    '挂号',
    NEW.registration_id,
    CONCAT('患者编号 ', NEW.patient_id, ' 挂 ', NEW.reg_type, '，排队号：', NEW.queue_no)
  );
END$$

-- 2. 收费后自动写日志（挂号费、药品费）
CREATE TRIGGER trg_payment_log
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
  INSERT INTO operation_logs (user_id, business_type, business_id, operation_content)
  VALUES (
    NEW.operator_id,
    '收费',
    NEW.payment_id,
    CONCAT(NEW.payment_type, '收费：', NEW.pay_amount, '元，支付方式：', NEW.pay_method)
  );
END$$

-- 3. 新增患者档案自动写日志
CREATE TRIGGER trg_patient_log
AFTER INSERT ON patients
FOR EACH ROW
BEGIN
  INSERT INTO operation_logs (user_id, business_type, business_id, operation_content)
  VALUES (
    NULL,
    '患者建档',
    NEW.patient_id,
    CONCAT('新建患者档案：', NEW.patient_name, '，病历号：', NEW.patient_no)
  );
END$$

-- 4. 排班停诊保护：已产生挂号的排班不允许直接停诊
CREATE TRIGGER trg_schedule_guard
BEFORE UPDATE ON doctor_schedules
FOR EACH ROW
BEGIN
  IF NEW.schedule_status = '停诊'
     AND OLD.schedule_status <> '停诊'
     AND NEW.registered_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '该排班已有患者挂号，不能停诊，请先完成退号';
  END IF;
END$$

DELIMITER ;
