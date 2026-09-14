-- 酒店人事一体化综合管理系统：触发器

USE hotel_hr_system;

DROP TRIGGER IF EXISTS trg_employee_leave_lock_account;
DROP TRIGGER IF EXISTS trg_checkout_update_room_status;
DROP TRIGGER IF EXISTS trg_work_order_insert_log;
DROP TRIGGER IF EXISTS trg_work_order_finish_update_room;

DELIMITER $$

-- 1. 员工离职后自动锁定对应登录账号
CREATE TRIGGER trg_employee_leave_lock_account
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
  IF NEW.employment_status = '离职'
     AND OLD.employment_status <> '离职' THEN
    UPDATE user_accounts
    SET account_status = '锁定'
    WHERE employee_id = NEW.employee_id;

    INSERT INTO operation_logs (employee_id, business_type, business_id, operation_content)
    VALUES (NEW.employee_id, '员工离职', NEW.employee_id, CONCAT('员工离职，账号自动锁定：', NEW.employee_name));
  END IF;
END$$

-- 2. 退房后自动更新客房状态为“待打扫”
CREATE TRIGGER trg_checkout_update_room_status
AFTER UPDATE ON checkin_orders
FOR EACH ROW
BEGIN
  IF NEW.order_status = '已退房'
     AND OLD.order_status <> '已退房' THEN
    UPDATE rooms
    SET room_status = '待打扫'
    WHERE room_id = NEW.room_id;
  END IF;
END$$

-- 3. 新增业务工单时写入操作日志
CREATE TRIGGER trg_work_order_insert_log
AFTER INSERT ON work_orders
FOR EACH ROW
BEGIN
  INSERT INTO operation_logs (employee_id, business_type, business_id, operation_content)
  VALUES (
    NEW.employee_id,
    CONCAT('新增', NEW.order_type, '工单'),
    NEW.work_order_id,
    CONCAT('新增工单：', NEW.work_order_no, '，负责员工编号：', NEW.employee_id)
  );
END$$

-- 4. 保洁工单完成后自动把“待打扫”房间改为空闲，维修工单完成后把“维修”房间改为空闲
CREATE TRIGGER trg_work_order_finish_update_room
AFTER UPDATE ON work_orders
FOR EACH ROW
BEGIN
  IF NEW.order_status = '已完成'
     AND OLD.order_status <> '已完成' THEN
    IF NEW.order_type = '保洁' THEN
      UPDATE rooms
      SET room_status = '空闲'
      WHERE room_id = NEW.room_id AND room_status = '待打扫';
    ELSEIF NEW.order_type = '维修' THEN
      UPDATE rooms
      SET room_status = '空闲'
      WHERE room_id = NEW.room_id AND room_status = '维修';
    END IF;

    INSERT INTO operation_logs (employee_id, business_type, business_id, operation_content)
    VALUES (
      NEW.employee_id,
      CONCAT(NEW.order_type, '工单完成'),
      NEW.work_order_id,
      CONCAT('完成工单：', NEW.work_order_no)
    );
  END IF;
END$$

DELIMITER ;
