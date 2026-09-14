-- 医院门诊管理系统：测试数据
-- 建议执行顺序：01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07
-- 演示完整门诊业务：挂号 -> 就诊开方 -> 收费 -> 退费 / 退号

USE hospital_outpatient;

-- 一、角色
INSERT INTO roles (role_code, role_name, description) VALUES
('ADMIN', '管理员', '系统管理与全部业务权限'),
('DOCTOR', '医生', '查看挂号、开具处方、管理患者'),
('REGISTRAR', '挂号员', '患者建档、挂号、退号'),
('CASHIER', '收费员', '处方收费、退费、报表');

-- 二、科室
INSERT INTO departments (department_code, department_name, description) VALUES
('NK', '内科', '心血管、呼吸、消化等内科疾病'),
('WK', '外科', '普外科、创伤等外科疾病'),
('EK', '儿科', '儿童常见病诊治'),
('FK', '妇产科', '妇科、产科门诊'),
('GK', '骨科', '骨伤、关节、脊柱疾病'),
('YK', '眼科', '眼部疾病诊治'),
('PFK', '皮肤科', '皮肤常见病诊治'),
('KQK', '口腔科', '口腔常见病诊治');

-- 三、系统用户与医生
-- 管理员、挂号员、收费员
CALL sp_add_user('A0001', '系统管理员', '男', NULL, 1, '13700000001', 'admin01', SHA2('123456', 256));
CALL sp_add_user('R0001', '挂号员小王', '女', NULL, 3, '13700000002', 'reg01', SHA2('123456', 256));
CALL sp_add_user('C0001', '收费员小李', '女', NULL, 4, '13700000003', 'cash01', SHA2('123456', 256));

-- 医生（sp_add_doctor 内部自动关联 DOCTOR 角色）
CALL sp_add_doctor('D001', '张建国', '男', 1, '13700000011', 'doctor01', SHA2('123456', 256), '主任医师', '心血管内科', 50.00, 30);
SET @d1 = LAST_INSERT_ID();
CALL sp_add_doctor('D002', '李慧', '女', 1, '13700000012', 'doctor02', SHA2('123456', 256), '主治医师', '呼吸系统疾病', 25.00, 40);
SET @d2 = LAST_INSERT_ID();
CALL sp_add_doctor('D003', '王志强', '男', 2, '13700000013', 'doctor03', SHA2('123456', 256), '主任医师', '普外科', 50.00, 30);
SET @d3 = LAST_INSERT_ID();
CALL sp_add_doctor('D004', '陈静', '女', 2, '13700000014', 'doctor04', SHA2('123456', 256), '主治医师', '创伤外科', 25.00, 40);
SET @d4 = LAST_INSERT_ID();
CALL sp_add_doctor('D005', '刘小梅', '女', 3, '13700000015', 'doctor05', SHA2('123456', 256), '副主任医师', '小儿内科', 30.00, 35);
SET @d5 = LAST_INSERT_ID();
CALL sp_add_doctor('D006', '赵红', '女', 4, '13700000016', 'doctor06', SHA2('123456', 256), '副主任医师', '围产医学', 40.00, 30);
SET @d6 = LAST_INSERT_ID();
CALL sp_add_doctor('D007', '孙强', '男', 5, '13700000017', 'doctor07', SHA2('123456', 256), '主治医师', '创伤骨科', 30.00, 35);
SET @d7 = LAST_INSERT_ID();
CALL sp_add_doctor('D008', '周敏', '女', 6, '13700000018', 'doctor08', SHA2('123456', 256), '副主任医师', '眼底病', 25.00, 40);
SET @d8 = LAST_INSERT_ID();

-- 四、患者档案
INSERT INTO patients (patient_no, patient_name, gender, birth_date, id_card, phone, address, blood_type, medical_history) VALUES
('P001', '王小明', '男', '1990-05-12', '330102199005120011', '13800001001', '杭州市西湖区文一路100号', 'A', '无'),
('P002', '李芳', '女', '1985-11-03', '330102198511030022', '13800001002', '杭州市拱墅区湖墅南路50号', 'O', '高血压病史'),
('P003', '张伟', '男', '1978-02-20', '330102197802200033', '13800001003', '杭州市上城区解放路20号', 'B', '糖尿病'),
('P004', '赵丽', '女', '1995-07-08', '330102199507080044', '13800001004', '杭州市滨江区江陵路66号', 'AB', '无'),
('P005', '陈强', '男', '2016-09-15', '330102201609150055', '13800001005', '杭州市西湖区学院路88号', '未知', '过敏性鼻炎'),
('P006', '刘洋', '男', '1988-12-25', '330102198812250066', '13800001006', '杭州市余杭区文一西路969号', 'O', '无'),
('P007', '孙悦', '女', '1992-03-30', '330102199203300077', '13800001007', '杭州市萧山区市心中路8号', 'A', '无'),
('P008', '周杰', '男', '1970-06-18', '330102197006180088', '13800001008', '杭州市临平区人民大道1号', 'B', '胃溃疡病史');

-- 五、药品目录
INSERT INTO medicines (medicine_code, medicine_name, specification, unit, manufacturer, unit_price, stock_quantity, medicine_type) VALUES
('M001', '阿莫西林胶囊', '0.25g*24粒', '盒', '华北制药', 15.80, 500, '西药'),
('M002', '布洛芬缓释胶囊', '0.3g*20粒', '盒', '中美史克', 18.50, 300, '西药'),
('M003', '感冒灵颗粒', '10g*9袋', '盒', '999制药', 12.00, 400, '中成药'),
('M004', '头孢克肟分散片', '50mg*12片', '盒', '广州白云山', 22.60, 260, '西药'),
('M005', '奥美拉唑肠溶胶囊', '20mg*14粒', '盒', '阿斯利康', 35.00, 200, '西药'),
('M006', '蒙脱石散', '3g*10袋', '盒', '博福-益普生', 19.80, 180, '西药'),
('M007', '小儿氨酚黄那敏颗粒', '2g*12袋', '盒', '哈药集团', 10.50, 350, '西药'),
('M008', '藿香正气口服液', '10ml*10支', '盒', '太极集团', 15.00, 220, '中成药'),
('M009', '云南白药气雾剂', '85g+30g', '盒', '云南白药', 32.00, 120, '外用'),
('M010', '碘伏消毒液', '100ml', '瓶', '利尔康', 6.50, 260, '外用'),
('M011', '生理盐水', '500ml', '瓶', '双鹤药业', 4.80, 400, '注射剂'),
('M012', '维生素C片', '100mg*100片', '瓶', '东北制药', 8.00, 500, '西药'),
('M013', '阿司匹林肠溶片', '100mg*30片', '盒', '拜耳', 16.80, 240, '西药'),
('M014', '复方丹参滴丸', '27mg*180丸', '盒', '天士力', 26.50, 190, '中成药'),
('M015', '左氧氟沙星滴眼液', '5ml', '瓶', '参天制药', 28.00, 150, '外用'),
('M016', '医用纱布块', '8cm*8cm*5片', '包', '稳健医疗', 4.20, 300, '外用');

-- 六、医生排班（今日 + 未来两天）
INSERT INTO doctor_schedules (doctor_id, work_date, shift_type, clinic_room, max_registrations) VALUES
(@d1, CURDATE(), '上午', '内科1诊室', 30),
(@d2, CURDATE(), '上午', '内科2诊室', 40),
(@d3, CURDATE(), '下午', '外科1诊室', 30),
(@d4, CURDATE(), '上午', '外科2诊室', 40),
(@d5, CURDATE(), '上午', '儿科1诊室', 35),
(@d6, CURDATE(), '下午', '妇产科1诊室', 30),
(@d7, CURDATE(), '上午', '骨科1诊室', 35),
(@d8, CURDATE(), '下午', '眼科1诊室', 40);
SET @s1 = 1;
SET @s2 = 2;
SET @s3 = 3;
SET @s4 = 4;
SET @s5 = 5;
SET @s6 = 6;
SET @s7 = 7;
SET @s8 = 8;

INSERT INTO doctor_schedules (doctor_id, work_date, shift_type, clinic_room, max_registrations) VALUES
(@d1, DATE_ADD(CURDATE(), INTERVAL 1 DAY), '上午', '内科1诊室', 30),
(@d2, DATE_ADD(CURDATE(), INTERVAL 1 DAY), '全天', '内科2诊室', 40),
(@d5, DATE_ADD(CURDATE(), INTERVAL 1 DAY), '上午', '儿科1诊室', 35),
(@d7, DATE_ADD(CURDATE(), INTERVAL 2 DAY), '上午', '骨科1诊室', 35);

-- 七、挂号业务演示（挂号员 reg01 用户ID=2，挂号费随挂号即时收取）
CALL sp_register('REG202609140001', 1, @d2, @s2, '普通号', 2, '微信');
CALL sp_register('REG202609140002', 2, @d1, @s1, '专家号', 2, '医保');
CALL sp_register('REG202609140003', 3, @d3, @s3, '专家号', 2, '支付宝');
CALL sp_register('REG202609140004', 4, @d4, @s4, '普通号', 2, '现金');
CALL sp_register('REG202609140005', 5, @d5, @s5, '普通号', 2, '微信');
CALL sp_register('REG202609140006', 6, @d7, @s7, '普通号', 2, '微信');
CALL sp_register('REG202609140007', 7, @d6, @s6, '专家号', 2, '医保');

-- 八、退号演示：刘洋（挂号记录6）退号，恢复骨科号源并退回挂号费
CALL sp_cancel_registration(6, 2, '临时有事，改日再诊');

-- 九、开具处方与收费退费演示（医生开方 -> 收费员收费/退费）
-- 处方1：王小明（挂号1，李慧医生），收费后已收费
CALL sp_issue_prescription(
  'PRES202609140001', 1, @d2, 1,
  '[{"medicine_id":1,"quantity":2,"dosage":"每日3次，每次1粒，饭后服"},
    {"medicine_id":3,"quantity":2,"dosage":"每日3次，每次1袋，开水冲服"}]'
);
CALL sp_charge(1, 3, 'PAY20260914000201', '微信');

-- 处方2：赵丽（挂号4，陈静医生），保持待收费状态
CALL sp_issue_prescription(
  'PRES202609140002', 4, @d4, 4,
  '[{"medicine_id":4,"quantity":1,"dosage":"每日2次，每次1片"},
    {"medicine_id":2,"quantity":1,"dosage":"疼痛时1粒，每日不超过3粒"},
    {"medicine_id":16,"quantity":2,"dosage":"外用，换药时使用"}]'
);

-- 处方3：李芳（挂号2，张建国医生），收费后演示退费
CALL sp_issue_prescription(
  'PRES202609140003', 2, @d1, 2,
  '[{"medicine_id":5,"quantity":1,"dosage":"每日1次，每次1粒，晨起空腹"},
    {"medicine_id":14,"quantity":2,"dosage":"每日3次，每次10丸"}]'
);
CALL sp_charge(3, 3, 'PAY20260914000301', '医保');
CALL sp_refund(3, 3, '患者拒收药品，申请退费');

-- 十、常用检查语句
SELECT * FROM v_today_registrations;
SELECT * FROM v_doctor_schedule WHERE work_date = CURDATE();
SELECT * FROM v_prescription_detail ORDER BY prescription_id;
SELECT * FROM v_daily_payment;
SELECT * FROM v_doctor_workload;
SELECT * FROM operation_logs ORDER BY created_at DESC LIMIT 10;
