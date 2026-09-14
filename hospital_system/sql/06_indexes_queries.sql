-- 医院门诊管理系统：索引、复杂查询与统计查询

USE hospital_outpatient;

-- 一、常用字段索引
CREATE INDEX idx_reg_date_status ON registrations(reg_date, visit_status);
CREATE INDEX idx_reg_patient ON registrations(patient_id);
CREATE INDEX idx_reg_doctor_date ON registrations(doctor_id, reg_date);
CREATE INDEX idx_schedule_date ON doctor_schedules(work_date);
CREATE INDEX idx_prescription_status ON prescriptions(prescription_status);
CREATE INDEX idx_prescription_patient ON prescriptions(patient_id);
CREATE INDEX idx_payment_status_time ON payments(pay_status, pay_time);
CREATE INDEX idx_payment_patient ON payments(patient_id);
CREATE INDEX idx_medicine_status ON medicines(status);
CREATE INDEX idx_logs_created_at ON operation_logs(created_at);

-- 二、多表联查：今日挂号明细（患者、医生、科室、就诊状态）
SELECT
  r.reg_no,
  pat.patient_name,
  pat.phone,
  dept.department_name,
  doc.user_name AS doctor_name,
  r.reg_type,
  r.reg_fee,
  r.queue_no,
  r.visit_status,
  r.created_at AS reg_time
FROM registrations r
JOIN patients pat ON r.patient_id = pat.patient_id
JOIN doctors d ON r.doctor_id = d.doctor_id
JOIN users doc ON d.user_id = doc.user_id
JOIN departments dept ON r.department_id = dept.department_id
WHERE r.reg_date = CURDATE()
ORDER BY r.visit_status, r.queue_no;

-- 三、分组统计：各科室今日挂号数与挂号费
SELECT
  dept.department_name,
  COUNT(r.registration_id) AS reg_count,
  SUM(r.reg_fee) AS reg_fee_total
FROM departments dept
LEFT JOIN registrations r ON dept.department_id = r.department_id AND r.reg_date = CURDATE()
GROUP BY dept.department_id, dept.department_name
ORDER BY reg_count DESC;

-- 四、子查询：查询挂号费高于当日平均挂号费的挂号记录
SELECT
  r.reg_no,
  pat.patient_name,
  dept.department_name,
  r.reg_type,
  r.reg_fee
FROM registrations r
JOIN patients pat ON r.patient_id = pat.patient_id
JOIN departments dept ON r.department_id = dept.department_id
WHERE r.reg_date = CURDATE()
  AND r.reg_fee > (
    SELECT AVG(r2.reg_fee)
    FROM registrations r2
    WHERE r2.reg_date = CURDATE()
  )
ORDER BY r.reg_fee DESC;

-- 五、收费统计：按支付方式统计收费金额
SELECT
  pay_method,
  COUNT(*) AS charge_count,
  SUM(pay_amount) AS total_amount
FROM payments
WHERE pay_status = '已收费'
GROUP BY pay_method
ORDER BY total_amount DESC;

-- 六、处方明细查询（视图）
SELECT * FROM v_prescription_detail ORDER BY prescribe_date DESC, prescription_id DESC;

-- 七、医生工作量与处方金额统计
SELECT
  doctor_name,
  department_name,
  prescription_count,
  total_amount
FROM v_doctor_workload
ORDER BY total_amount DESC;

-- 八、收费日报
SELECT * FROM v_daily_payment ORDER BY pay_date DESC;
