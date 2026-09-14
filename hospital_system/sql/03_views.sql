-- 医院门诊管理系统：业务视图

USE hospital_outpatient;

DROP VIEW IF EXISTS v_today_registrations;
DROP VIEW IF EXISTS v_doctor_schedule;
DROP VIEW IF EXISTS v_prescription_detail;
DROP VIEW IF EXISTS v_daily_payment;
DROP VIEW IF EXISTS v_doctor_workload;

-- 1. 当日挂号统计视图：按科室统计当日挂号数、普通号/专家号数量与挂号费
CREATE VIEW v_today_registrations AS
SELECT
  d.department_name,
  COUNT(r.registration_id) AS registration_count,
  SUM(CASE WHEN r.reg_type = '普通号' THEN 1 ELSE 0 END) AS normal_count,
  SUM(CASE WHEN r.reg_type = '专家号' THEN 1 ELSE 0 END) AS expert_count,
  SUM(r.reg_fee) AS total_fee,
  SUM(CASE WHEN r.visit_status = '已退号' THEN 1 ELSE 0 END) AS cancelled_count
FROM registrations r
JOIN departments d ON r.department_id = d.department_id
WHERE r.reg_date = CURDATE()
GROUP BY d.department_id, d.department_name;

-- 2. 医生排班视图：展示医生、科室、日期、班次、诊室、号源与剩余号
CREATE VIEW v_doctor_schedule AS
SELECT
  s.schedule_id,
  s.work_date,
  s.shift_type,
  s.clinic_room,
  s.max_registrations,
  s.registered_count,
  GREATEST(s.max_registrations - s.registered_count, 0) AS remain_count,
  s.schedule_status,
  doc.doctor_no,
  doc.doctor_name,
  doc.title,
  doc.specialty,
  doc.consultation_fee,
  dept.department_name
FROM doctor_schedules s
JOIN (
  SELECT d.doctor_id, d.doctor_no, d.title, d.specialty, d.consultation_fee,
         u.user_name AS doctor_name, u.department_id
  FROM doctors d
  JOIN users u ON d.user_id = u.user_id
) doc ON s.doctor_id = doc.doctor_id
JOIN departments dept ON doc.department_id = dept.department_id;

-- 3. 处方明细视图：展示处方、患者、医生、药品与金额状态
CREATE VIEW v_prescription_detail AS
SELECT
  p.prescription_id,
  p.prescription_no,
  p.prescribe_date,
  p.total_amount,
  p.prescription_status,
  pat.patient_no,
  pat.patient_name,
  u.user_name AS doctor_name,
  d.department_name,
  GROUP_CONCAT(CONCAT(pi.medicine_name, ' x', pi.quantity) SEPARATOR '；') AS medicine_summary
FROM prescriptions p
JOIN patients pat ON p.patient_id = pat.patient_id
JOIN doctors doc ON p.doctor_id = doc.doctor_id
JOIN users u ON doc.user_id = u.user_id
JOIN departments d ON u.department_id = d.department_id
LEFT JOIN prescription_items pi ON p.prescription_id = pi.prescription_id
GROUP BY
  p.prescription_id, p.prescription_no, p.prescribe_date, p.total_amount,
  p.prescription_status, pat.patient_no, pat.patient_name,
  u.user_name, d.department_name;

-- 4. 收费日报视图：按日统计收费金额与退费金额
CREATE VIEW v_daily_payment AS
SELECT
  DATE(pay_time) AS pay_date,
  COUNT(CASE WHEN pay_status = '已收费' THEN 1 END) AS charge_count,
  SUM(CASE WHEN pay_status = '已收费' THEN pay_amount ELSE 0 END) AS charge_amount,
  COUNT(CASE WHEN pay_status = '已退费' THEN 1 END) AS refund_count,
  SUM(CASE WHEN pay_status = '已退费' THEN pay_amount ELSE 0 END) AS refund_amount,
  SUM(CASE WHEN pay_status = '已收费' THEN pay_amount ELSE -pay_amount END) AS net_amount
FROM payments
GROUP BY DATE(pay_time);

-- 5. 医生工作量视图：按医生统计处方数与处方金额
CREATE VIEW v_doctor_workload AS
SELECT
  u.user_name AS doctor_name,
  d.department_name,
  COUNT(p.prescription_id) AS prescription_count,
  COALESCE(SUM(p.total_amount), 0) AS total_amount
FROM doctors doc
JOIN users u ON doc.user_id = u.user_id
JOIN departments d ON u.department_id = d.department_id
LEFT JOIN prescriptions p ON doc.doctor_id = p.doctor_id
GROUP BY u.user_id, u.user_name, d.department_name;
