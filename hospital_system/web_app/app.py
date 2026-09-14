"""
医院门诊管理系统（对标小型 HIS 门诊业务）Web 版。
启动方式：python app.py
访问地址：http://127.0.0.1:5000

模块：患者档案、挂号、医生排班、处方开具、收费退费、药品目录、报表查询。
角色：ADMIN 管理员 / DOCTOR 医生 / REGISTRAR 挂号员 / CASHIER 收费员
"""

import csv
import hashlib
import json
from datetime import datetime
from functools import wraps
from pathlib import Path

import mysql.connector
from flask import Flask, Response, flash, redirect, render_template, request, session, url_for

from db import call_proc, execute, fetch_all, fetch_one, get_connection


app = Flask(__name__)
app.secret_key = "hospital-outpatient-his-course-design"

EXPORT_DIR = Path(__file__).resolve().parent / "exports"


def sha256_text(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def current_user():
    return session.get("user")


def login_required(view_func):
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        if not current_user():
            return redirect(url_for("login"))
        return view_func(*args, **kwargs)

    return wrapper


PERMISSIONS = {
    "REGISTRAR": {"dashboard", "patients", "registrations", "schedules", "reports", "export", "codes"},
    "DOCTOR": {"dashboard", "patients", "registrations", "prescriptions", "schedules", "reports", "export", "codes"},
    "CASHIER": {"dashboard", "payments", "medicines", "reports", "export", "codes"},
    "ADMIN": {"dashboard", "patients", "registrations", "schedules", "prescriptions",
              "payments", "medicines", "reports", "export", "codes"},
}


def role_allowed(menu_key):
    user = current_user()
    if not user:
        return False
    if user["role_code"] == "ADMIN":
        return True
    return menu_key in PERMISSIONS.get(user["role_code"], set())


def permission_required(menu_key):
    def decorator(view_func):
        @wraps(view_func)
        def wrapper(*args, **kwargs):
            if not role_allowed(menu_key):
                flash("当前角色无权访问该功能。", "error")
                return redirect(url_for("dashboard"))
            return view_func(*args, **kwargs)

        return wrapper

    return decorator


@app.context_processor
def inject_common_data():
    return {
        "current_user": current_user(),
        "role_allowed": role_allowed,
        "now": datetime.now(),
    }


def handle_db_error(error):
    message = str(error)
    # 存储过程 SIGNAL 抛出的业务错误（1644 为 SIGNAL 的错误码）
    if "1644" in message:
        try:
            return message.split(": ", 2)[2]
        except IndexError:
            return "业务规则校验未通过。"
    if "Duplicate entry" in message:
        return "数据重复：病历号、身份证号、手机号、登录名等唯一字段不能重复。"
    if "Cannot delete or update a parent row" in message:
        return "该数据已被挂号、处方或收费记录引用，不能直接删除。"
    if "Incorrect datetime value" in message or "Incorrect date value" in message:
        return "日期格式错误：日期用 2026-09-14，日期时间用 2026-09-14 08:00:00。"
    return f"数据库操作失败：{message}"


def make_no(prefix):
    return prefix + datetime.now().strftime("%Y%m%d%H%M%S")


# ============================================================
# 登录 / 退出
# ============================================================

@app.route("/", methods=["GET"])
def index():
    if current_user():
        return redirect(url_for("dashboard"))
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()
        user = fetch_one(
            """
            SELECT
              u.user_id, u.user_name, u.username, u.account_status,
              r.role_code, r.role_name, d.department_name
            FROM users u
            JOIN roles r ON u.role_id = r.role_id
            LEFT JOIN departments d ON u.department_id = d.department_id
            WHERE u.username = %s AND u.password_hash = %s
            """,
            (username, sha256_text(password)),
        )
        if not user:
            flash("用户名或密码错误。", "error")
            return render_template("login.html")
        if user["account_status"] != "启用":
            flash("账号已被锁定，无法登录。", "error")
            return render_template("login.html")
        session["user"] = user
        execute("UPDATE users SET last_login_at = NOW() WHERE user_id = %s", (user["user_id"],))
        flash(f"登录成功：{user['user_name']}（{user['role_name']}）", "success")
        return redirect(url_for("dashboard"))
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("已退出登录。", "success")
    return redirect(url_for("login"))


# ============================================================
# 首页看板
# ============================================================

@app.route("/dashboard")
@login_required
def dashboard():
    today = datetime.now().strftime("%Y-%m-%d")
    stats = {
        "today_reg": fetch_one(
            "SELECT COUNT(*) AS v FROM registrations WHERE reg_date = %s AND visit_status <> '已退号'", (today,)
        )["v"],
        "today_visited": fetch_one(
            "SELECT COUNT(*) AS v FROM registrations WHERE reg_date = %s AND visit_status = '已就诊'", (today,)
        )["v"],
        "waiting_pres": fetch_one(
            "SELECT COUNT(*) AS v FROM prescriptions WHERE prescription_status = '待收费'"
        )["v"],
        "today_income": fetch_one(
            """
            SELECT COALESCE(SUM(pay_amount), 0) AS v FROM payments
            WHERE DATE(pay_time) = %s AND pay_status = '已收费'
            """,
            (today,),
        )["v"],
    }
    reg_by_dept = fetch_all("SELECT * FROM v_today_registrations ORDER BY registration_count DESC")
    today_occupied = fetch_all(
        """
        SELECT r.reg_no, pat.patient_name, dept.department_name, u.user_name AS doctor_name,
               r.reg_type, r.queue_no, r.visit_status, r.reg_fee
        FROM registrations r
        JOIN patients pat ON r.patient_id = pat.patient_id
        JOIN departments dept ON r.department_id = dept.department_id
        JOIN doctors doc ON r.doctor_id = doc.doctor_id
        JOIN users u ON doc.user_id = u.user_id
        WHERE r.reg_date = %s
        ORDER BY CASE r.visit_status WHEN '待就诊' THEN 0 WHEN '就诊中' THEN 1 ELSE 2 END, r.queue_no
        """,
        (today,),
    )
    return render_template("dashboard.html", stats=stats, reg_by_dept=reg_by_dept, today_occupied=today_occupied)


# ============================================================
# 患者档案管理
# ============================================================

@app.route("/patients", methods=["GET", "POST"])
@login_required
@permission_required("patients")
def patients():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "add":
                execute(
                    """
                    INSERT INTO patients (patient_no, patient_name, gender, birth_date,
                                          id_card, phone, address, blood_type, medical_history)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        request.form["patient_no"].strip(),
                        request.form["patient_name"].strip(),
                        request.form["gender"],
                        request.form["birth_date"] or None,
                        request.form["id_card"].strip(),
                        request.form["phone"].strip(),
                        request.form.get("address") or None,
                        request.form["blood_type"],
                        request.form.get("medical_history") or None,
                    ),
                )
                flash("患者档案创建成功。", "success")
            elif action == "update":
                execute(
                    """
                    UPDATE patients
                    SET phone = %s, address = %s, blood_type = %s, medical_history = %s
                    WHERE patient_id = %s
                    """,
                    (
                        request.form["phone"].strip(),
                        request.form.get("address") or None,
                        request.form["blood_type"],
                        request.form.get("medical_history") or None,
                        request.form["patient_id"],
                    ),
                )
                flash("患者档案已更新。", "success")
            elif action == "delete":
                execute("DELETE FROM patients WHERE patient_id = %s", (request.form["patient_id"],))
                flash("患者档案已删除。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("patients"))

    keyword = request.args.get("keyword", "").strip()
    if keyword:
        like = f"%{keyword}%"
        rows = fetch_all(
            """
            SELECT * FROM patients
            WHERE patient_name LIKE %s OR id_card LIKE %s OR phone LIKE %s OR patient_no LIKE %s
            ORDER BY patient_id
            """,
            (like, like, like, like),
        )
    else:
        rows = fetch_all("SELECT * FROM patients ORDER BY patient_id")
    return render_template("patients.html", rows=rows, keyword=keyword)


# ============================================================
# 挂号管理
# ============================================================

@app.route("/registrations", methods=["GET", "POST"])
@login_required
@permission_required("registrations")
def registrations():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "register":
                schedule = fetch_one(
                    "SELECT doctor_id FROM doctor_schedules WHERE schedule_id = %s",
                    (request.form["schedule_id"],),
                )
                if not schedule:
                    flash("排班不存在，请刷新后重试。", "error")
                    return redirect(url_for("registrations"))
                call_proc(
                    "sp_register",
                    [
                        make_no("REG"),
                        int(request.form["patient_id"]),
                        schedule["doctor_id"],
                        int(request.form["schedule_id"]),
                        request.form["reg_type"],
                        int(current_user()["user_id"]),
                        request.form["pay_method"],
                    ],
                )
                flash("挂号成功，挂号费已收取。", "success")
            elif action == "cancel":
                call_proc(
                    "sp_cancel_registration",
                    [
                        int(request.form["registration_id"]),
                        int(current_user()["user_id"]),
                        request.form.get("reason") or "患者申请退号",
                    ],
                )
                flash("退号成功，号源已恢复，挂号费已退回。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("registrations"))

    reg_date = request.args.get("reg_date") or datetime.now().strftime("%Y-%m-%d")
    rows = fetch_all(
        """
        SELECT r.registration_id, r.reg_no, pat.patient_name, dept.department_name,
               u.user_name AS doctor_name, r.reg_type, r.reg_fee, r.queue_no,
               r.visit_status, r.created_at AS reg_time
        FROM registrations r
        JOIN patients pat ON r.patient_id = pat.patient_id
        JOIN departments dept ON r.department_id = dept.department_id
        JOIN doctors doc ON r.doctor_id = doc.doctor_id
        JOIN users u ON doc.user_id = u.user_id
        WHERE r.reg_date = %s
        ORDER BY r.queue_no
        """,
        (reg_date,),
    )
    patients_rows = fetch_all("SELECT patient_id, patient_no, patient_name, phone FROM patients ORDER BY patient_id")
    schedules = fetch_all(
        """
        SELECT s.schedule_id, s.work_date, s.shift_type, s.clinic_room,
               s.max_registrations, s.registered_count,
               doc.doctor_id, doc.doctor_name, doc.title,
               dept.department_name, doc.consultation_fee,
               GREATEST(s.max_registrations - s.registered_count, 0) AS remain
        FROM doctor_schedules s
        JOIN (
          SELECT d.doctor_id, u.user_name AS doctor_name, d.title, d.consultation_fee, u.department_id
          FROM doctors d JOIN users u ON d.user_id = u.user_id
        ) doc ON s.doctor_id = doc.doctor_id
        JOIN departments dept ON doc.department_id = dept.department_id
        WHERE s.work_date = %s AND s.schedule_status = '正常'
        ORDER BY s.work_date, dept.department_name
        """,
        (reg_date,),
    )
    return render_template("registrations.html", rows=rows, patients=patients_rows,
                           schedules=schedules, reg_date=reg_date)


# ============================================================
# 医生排班管理
# ============================================================

@app.route("/schedules", methods=["GET", "POST"])
@login_required
@permission_required("schedules")
def schedules():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "add":
                execute(
                    """
                    INSERT INTO doctor_schedules (doctor_id, work_date, shift_type, clinic_room, max_registrations)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (
                        request.form["doctor_id"],
                        request.form["work_date"],
                        request.form["shift_type"],
                        request.form.get("clinic_room") or None,
                        int(request.form["max_registrations"]),
                    ),
                )
                flash("排班创建成功。", "success")
            elif action == "status":
                execute(
                    "UPDATE doctor_schedules SET schedule_status = %s WHERE schedule_id = %s",
                    (request.form["schedule_status"], request.form["schedule_id"]),
                )
                flash("排班状态已更新。", "success")
            elif action == "delete":
                execute("DELETE FROM doctor_schedules WHERE schedule_id = %s", (request.form["schedule_id"],))
                flash("排班已删除。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("schedules"))

    work_date = request.args.get("work_date") or datetime.now().strftime("%Y-%m-%d")
    rows = fetch_all(
        """
        SELECT * FROM v_doctor_schedule
        WHERE work_date = %s
        ORDER BY department_name, shift_type
        """,
        (work_date,),
    )
    doctors = fetch_all(
        """
        SELECT d.doctor_id, u.user_name AS doctor_name, dept.department_name, d.title, d.consultation_fee
        FROM doctors d
        JOIN users u ON d.user_id = u.user_id
        JOIN departments dept ON u.department_id = dept.department_id
        ORDER BY dept.department_id, d.doctor_id
        """
    )
    return render_template("schedules.html", rows=rows, doctors=doctors, work_date=work_date)


# ============================================================
# 处方开具
# ============================================================

@app.route("/prescriptions", methods=["GET", "POST"])
@login_required
@permission_required("prescriptions")
def prescriptions():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "issue":
                medicine_ids = request.form.getlist("medicine_id[]")
                quantities = request.form.getlist("quantity[]")
                dosages = request.form.getlist("dosage[]")
                items = []
                for mid, qty, dosage in zip(medicine_ids, quantities, dosages):
                    if not mid.strip():
                        continue
                    items.append({
                        "medicine_id": int(mid),
                        "quantity": int(qty or 1),
                        "dosage": dosage.strip() or "",
                    })
                if not items:
                    flash("请至少添加一种药品。", "error")
                    return redirect(url_for("prescriptions"))
                registration_id = int(request.form["registration_id"]) if request.form.get("registration_id") else None
                reg_row = fetch_one(
                    "SELECT patient_id FROM registrations WHERE registration_id = %s", (registration_id,)
                ) if registration_id else None
                patient_id = reg_row["patient_id"] if reg_row else int(request.form["patient_id"])
                call_proc(
                    "sp_issue_prescription",
                    [
                        make_no("PRES"),
                        patient_id,
                        int(request.form["doctor_id"]),
                        registration_id,
                        json.dumps(items, ensure_ascii=False),
                    ],
                )
                flash("处方开具成功，状态为待收费。", "success")
            elif action == "void":
                execute(
                    "UPDATE prescriptions SET prescription_status = '已作废' WHERE prescription_id = %s",
                    (request.form["prescription_id"],),
                )
                flash("处方已作废。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("prescriptions"))

    status = request.args.get("status") or ""
    base_sql = """
        SELECT p.prescription_id, p.prescription_no, p.prescribe_date, p.total_amount,
               p.prescription_status, pat.patient_name, u.user_name AS doctor_name,
               dept.department_name
        FROM prescriptions p
        JOIN patients pat ON p.patient_id = pat.patient_id
        JOIN doctors doc ON p.doctor_id = doc.doctor_id
        JOIN users u ON doc.user_id = u.user_id
        JOIN departments dept ON u.department_id = dept.department_id
    """
    if status:
        rows = fetch_all(base_sql + " WHERE p.prescription_status = %s ORDER BY p.prescription_id DESC", (status,))
    else:
        rows = fetch_all(base_sql + " ORDER BY p.prescription_id DESC")

    # 开方所需的患者（今日已挂号待就诊/就诊中）
    registerable = fetch_all(
        """
        SELECT r.registration_id, r.reg_no, pat.patient_id, pat.patient_name, dept.department_name,
               u.user_name AS doctor_name, r.visit_status
        FROM registrations r
        JOIN patients pat ON r.patient_id = pat.patient_id
        JOIN departments dept ON r.department_id = dept.department_id
        JOIN doctors doc ON r.doctor_id = doc.doctor_id
        JOIN users u ON doc.user_id = u.user_id
        WHERE r.reg_date = CURDATE() AND r.visit_status IN ('待就诊','就诊中')
        ORDER BY r.queue_no
        """
    )
    medicines = fetch_all(
        "SELECT medicine_id, medicine_code, medicine_name, specification, unit, unit_price, stock_quantity FROM medicines WHERE status = '启用' ORDER BY medicine_name"
    )
    # 医生选择（DOCTOR 角色默认只开自己的方）
    doctors = fetch_all(
        """
        SELECT d.doctor_id, u.user_name AS doctor_name, dept.department_name
        FROM doctors d
        JOIN users u ON d.user_id = u.user_id
        JOIN departments dept ON u.department_id = dept.department_id
        ORDER BY dept.department_id
        """
    )
    return render_template("prescriptions.html", rows=rows, registerable=registerable,
                           medicines=medicines, doctors=doctors, status=status)


# ============================================================
# 收费退费
# ============================================================

@app.route("/payments", methods=["GET", "POST"])
@login_required
@permission_required("payments")
def payments():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "charge":
                call_proc(
                    "sp_charge",
                    [
                        int(request.form["prescription_id"]),
                        int(current_user()["user_id"]),
                        make_no("PAY"),
                        request.form["pay_method"],
                    ],
                )
                flash("收费成功，药品库存已扣减。", "success")
            elif action == "refund":
                call_proc(
                    "sp_refund",
                    [
                        int(request.form["prescription_id"]),
                        int(current_user()["user_id"]),
                        request.form.get("reason") or "患者申请退费",
                    ],
                )
                flash("退费成功，药品库存已恢复。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("payments"))

    waiting = fetch_all(
        """
        SELECT p.prescription_id, p.prescription_no, pat.patient_name, u.user_name AS doctor_name,
               p.total_amount, p.prescribe_date
        FROM prescriptions p
        JOIN patients pat ON p.patient_id = pat.patient_id
        JOIN doctors doc ON p.doctor_id = doc.doctor_id
        JOIN users u ON doc.user_id = u.user_id
        WHERE p.prescription_status = '待收费'
        ORDER BY p.prescription_id
        """
    )
    charged = fetch_all(
        """
        SELECT p.prescription_id, p.prescription_no, pat.patient_name, u.user_name AS doctor_name,
               p.total_amount, p.prescription_status,
               pm.payment_no, pm.pay_method, pm.pay_time, pm.refund_time, pm.refund_reason
        FROM prescriptions p
        JOIN patients pat ON p.patient_id = pat.patient_id
        JOIN doctors doc ON p.doctor_id = doc.doctor_id
        JOIN users u ON doc.user_id = u.user_id
        LEFT JOIN payments pm ON p.prescription_id = pm.prescription_id AND pm.payment_type = '药品费'
        WHERE p.prescription_status IN ('已收费','已退费')
        ORDER BY p.prescription_id DESC
        """
    )
    return render_template("payments.html", waiting=waiting, charged=charged)


# ============================================================
# 药品目录管理
# ============================================================

@app.route("/medicines", methods=["GET", "POST"])
@login_required
@permission_required("medicines")
def medicines():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "add":
                execute(
                    """
                    INSERT INTO medicines (medicine_code, medicine_name, specification, unit,
                                           manufacturer, unit_price, stock_quantity, medicine_type)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        request.form["medicine_code"].strip(),
                        request.form["medicine_name"].strip(),
                        request.form.get("specification") or None,
                        request.form["unit"],
                        request.form.get("manufacturer") or None,
                        float(request.form["unit_price"]),
                        int(request.form["stock_quantity"]),
                        request.form["medicine_type"],
                    ),
                )
                flash("药品新增成功。", "success")
            elif action == "update":
                execute(
                    """
                    UPDATE medicines
                    SET unit_price = %s, stock_quantity = %s, status = %s
                    WHERE medicine_id = %s
                    """,
                    (
                        float(request.form["unit_price"]),
                        int(request.form["stock_quantity"]),
                        request.form["status"],
                        request.form["medicine_id"],
                    ),
                )
                flash("药品信息已更新。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("medicines"))

    keyword = request.args.get("keyword", "").strip()
    if keyword:
        like = f"%{keyword}%"
        rows = fetch_all(
            "SELECT * FROM medicines WHERE medicine_name LIKE %s OR medicine_code LIKE %s ORDER BY medicine_id",
            (like, like),
        )
    else:
        rows = fetch_all("SELECT * FROM medicines ORDER BY medicine_id")
    return render_template("medicines.html", rows=rows, keyword=keyword)


# ============================================================
# 报表查询
# ============================================================

@app.route("/reports")
@login_required
@permission_required("reports")
def reports():
    data = {
        "reg": fetch_all("SELECT * FROM v_today_registrations ORDER BY registration_count DESC"),
        "schedule": fetch_all("SELECT * FROM v_doctor_schedule WHERE work_date = CURDATE() ORDER BY department_name"),
        "payment": fetch_all("SELECT * FROM v_daily_payment ORDER BY pay_date DESC"),
        "prescription": fetch_all("SELECT * FROM v_prescription_detail ORDER BY prescription_id DESC"),
        "workload": fetch_all("SELECT * FROM v_doctor_workload ORDER BY total_amount DESC"),
    }
    return render_template("reports.html", data=data, tab=request.args.get("tab", "reg"))


# ============================================================
# 编号参考
# ============================================================

@app.route("/codes")
@login_required
def codes():
    data = {
        "departments": fetch_all("SELECT department_id, department_code, department_name FROM departments ORDER BY department_id"),
        "roles": fetch_all("SELECT role_id, role_code, role_name FROM roles ORDER BY role_id"),
        "doctors": fetch_all(
            """
            SELECT d.doctor_id, d.doctor_no, u.user_name AS doctor_name, dept.department_name, d.title, d.consultation_fee
            FROM doctors d
            JOIN users u ON d.user_id = u.user_id
            JOIN departments dept ON u.department_id = dept.department_id
            ORDER BY d.doctor_id
            """
        ),
        "patients": fetch_all("SELECT patient_id, patient_no, patient_name, phone FROM patients ORDER BY patient_id"),
        "medicines": fetch_all("SELECT medicine_id, medicine_code, medicine_name, unit_price, stock_quantity FROM medicines ORDER BY medicine_id"),
        "users": fetch_all(
            """
            SELECT u.user_id, u.user_no, u.user_name, r.role_name, u.account_status
            FROM users u JOIN roles r ON u.role_id = r.role_id ORDER BY u.user_id
            """
        ),
    }
    return render_template("codes.html", data=data)


# ============================================================
# 数据导出（CSV）
# ============================================================

@app.route("/export/<name>")
@login_required
@permission_required("export")
def export_csv(name):
    queries = {
        "patients": ("患者档案", "SELECT * FROM patients"),
        "registrations": ("今日挂号", "SELECT * FROM registrations WHERE reg_date = CURDATE()"),
        "prescriptions": ("处方数据", "SELECT * FROM v_prescription_detail"),
        "payments": ("收费记录", "SELECT * FROM payments"),
        "medicines": ("药品目录", "SELECT * FROM medicines"),
    }
    if name not in queries:
        flash("导出类型不存在。", "error")
        return redirect(url_for("reports"))

    title, sql = queries[name]
    rows = fetch_all(sql)
    EXPORT_DIR.mkdir(exist_ok=True)
    output = []
    if rows:
        headers = list(rows[0].keys())
        output.append(",".join(headers))
        for row in rows:
            output.append(",".join(str(row.get(header, "")) for header in headers))
    else:
        output.append("暂无数据")
    csv_text = "\ufeff" + "\n".join(output)
    filename = f"{name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    return Response(
        csv_text,
        mimetype="text/csv; charset=utf-8",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
