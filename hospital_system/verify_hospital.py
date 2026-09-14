"""
医院门诊管理系统 Web 端到端验证脚本（黑盒冒烟测试）。

覆盖：登录 -> 各页面访问 -> 挂号 -> 开具处方 -> 收费 -> 退费 -> 退号。
运行前请确保：MySQL 已启动、数据库已初始化（init_database.py）、Web 已启动（python app.py）。
用法：python verify_hospital.py
"""

import http.cookiejar
import sys
import urllib.parse
import urllib.request
from pathlib import Path

BASE = "http://127.0.0.1:5000"
WEB_APP = Path(__file__).resolve().parent / "web_app"
sys.path.insert(0, str(WEB_APP))
from db import fetch_all, fetch_one  # noqa: E402

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))


def get(path):
    resp = opener.open(BASE + path, timeout=15)
    return resp.status, resp.read().decode("utf-8")


def post(path, data):
    body = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(BASE + path, data=body)
    resp = opener.open(req, timeout=15)
    return resp.status, resp.read().decode("utf-8")


def check(name, condition, extra=""):
    mark = "PASS" if condition else "FAIL"
    print(f"[{mark}] {name} {extra}")
    if not condition:
        raise SystemExit(f"验证失败：{name}")


def main():
    print("=" * 60)
    print("医院门诊管理系统 Web 端到端验证")
    print("=" * 60)

    # 1. 登录管理员
    status, html = post("/login", {"username": "admin01", "password": "123456"})
    check("管理员登录", "门诊运营看板" in html or "Dashboard" in html, f"(status={status})")

    # 2. 各页面可访问
    for path in [
        "/dashboard", "/patients", "/registrations", "/schedules",
        "/prescriptions", "/payments", "/medicines",
        "/reports", "/reports?tab=schedule", "/reports?tab=payment",
        "/reports?tab=prescription", "/reports?tab=workload", "/codes",
    ]:
        status, html = get(path)
        check(f"GET {path}", status == 200, f"(status={status})")

    # 3. 挂号：找一个有剩余号源的今日排班 + 患者
    schedule = fetch_one(
        """
        SELECT s.schedule_id, d.doctor_id
        FROM doctor_schedules s
        JOIN doctors d ON s.doctor_id = d.doctor_id
        WHERE s.work_date = CURDATE() AND s.schedule_status = '正常'
          AND s.registered_count < s.max_registrations
        ORDER BY s.registered_count ASC LIMIT 1
        """
    )
    patient = fetch_one("SELECT patient_id FROM patients ORDER BY patient_id DESC LIMIT 1")
    check("存在可用排班与患者", schedule is not None and patient is not None)
    status, html = post(
        "/registrations",
        {
            "action": "register",
            "patient_id": patient["patient_id"],
            "reg_type": "普通号",
            "schedule_id": schedule["schedule_id"],
            "pay_method": "现金",
        },
    )
    check("办理挂号", "挂号成功" in html)

    # 4. 开具处方
    reg = fetch_one("SELECT registration_id FROM registrations ORDER BY registration_id DESC LIMIT 1")
    med = fetch_one("SELECT medicine_id FROM medicines WHERE status = '启用' ORDER BY medicine_id LIMIT 1")
    status, html = post(
        "/prescriptions",
        {
            "action": "issue",
            "registration_id": reg["registration_id"],
            "doctor_id": schedule["doctor_id"],
            "medicine_id[]": med["medicine_id"],
            "quantity[]": "2",
            "dosage[]": "每日3次，每次1粒",
        },
    )
    check("开具处方", "处方开具成功" in html)

    # 5. 收费
    pres = fetch_one(
        "SELECT prescription_id FROM prescriptions WHERE prescription_status = '待收费' ORDER BY prescription_id DESC LIMIT 1"
    )
    status, html = post(
        "/payments", {"action": "charge", "prescription_id": pres["prescription_id"], "pay_method": "现金"}
    )
    check("处方收费", "收费成功" in html)

    # 6. 退费
    status, html = post(
        "/payments",
        {"action": "refund", "prescription_id": pres["prescription_id"], "reason": "自动化验证退费"},
    )
    check("处方退费", "退费成功" in html)

    # 7. 退号（若存在待就诊挂号）
    reg2 = fetch_one("SELECT registration_id FROM registrations WHERE visit_status = '待就诊' LIMIT 1")
    if reg2:
        status, html = post(
            "/registrations",
            {"action": "cancel", "registration_id": reg2["registration_id"], "reason": "自动化验证退号"},
        )
        check("办理退号", "退号成功" in html)
    else:
        print("[SKIP] 无待就诊挂号，跳过退号测试")

    # 8. 数据一致性核对
    counts = fetch_all(
        """
        SELECT
          (SELECT COUNT(*) FROM registrations) AS regs,
          (SELECT COUNT(*) FROM prescriptions) AS pres,
          (SELECT COUNT(*) FROM payments) AS pays,
          (SELECT COUNT(*) FROM operation_logs) AS logs
        """
    )[0]
    print("-" * 60)
    print(f"当前数据：挂号 {counts['regs']} 条 / 处方 {counts['pres']} 条 / 收费 {counts['pays']} 条 / 日志 {counts['logs']} 条")
    print("全部验证通过！")


if __name__ == "__main__":
    main()
