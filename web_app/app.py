"""
酒店人事一体化综合管理系统 Web 版。
启动方式：python app.py
访问地址：http://127.0.0.1:5000
"""

import csv
import hashlib
from datetime import datetime
from functools import wraps
from pathlib import Path

import mysql.connector
from flask import Flask, Response, flash, redirect, render_template, request, session, url_for

from db import call_proc, execute, fetch_all, fetch_one, get_connection


app = Flask(__name__)
app.secret_key = "hotel-hr-system-course-design"

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


def role_allowed(menu_key):
    user = current_user()
    if not user:
        return False
    role = user["role_code"]
    if role == "MANAGER":
        return True
    permissions = {
        "FRONT_DESK": {"dashboard", "rooms", "customers", "checkin", "checkout", "reports", "export"},
        "HR": {"dashboard", "rooms", "employees", "attendance", "reports", "export"},
        "FINANCE": {"dashboard", "salary", "reports", "export"},
    }
    return menu_key in permissions.get(role, set())


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
    if "Duplicate entry" in message:
        return "数据重复：订单号、手机号、证件号、工号等唯一字段不能重复。"
    if "Cannot delete or update a parent row" in message:
        return "该数据已被其他业务记录引用，不能直接删除。"
    if "Incorrect datetime value" in message or "Incorrect date value" in message:
        return "日期格式错误：日期用 2026-07-13，日期时间用 2026-07-13 12:00:00。"
    return f"数据库操作失败：{message}"


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
              ua.account_id, ua.employee_id, ua.username, ua.account_status,
              e.employee_name, r.role_code, r.role_name
            FROM user_accounts ua
            JOIN employees e ON ua.employee_id = e.employee_id
            JOIN roles r ON ua.role_id = r.role_id
            WHERE ua.username = %s AND ua.password_hash = %s
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
        execute("UPDATE user_accounts SET last_login_at = NOW() WHERE account_id = %s", (user["account_id"],))
        flash(f"登录成功：{user['employee_name']}（{user['role_name']}）", "success")
        return redirect(url_for("dashboard"))
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("已退出登录。", "success")
    return redirect(url_for("login"))


@app.route("/dashboard")
@login_required
def dashboard():
    stats = {
        "room_count": fetch_one("SELECT COUNT(*) AS value FROM rooms")["value"],
        "free_room_count": fetch_one("SELECT COUNT(*) AS value FROM rooms WHERE room_status = '空闲'")["value"],
        "living_order_count": fetch_one("SELECT COUNT(*) AS value FROM checkin_orders WHERE order_status = '入住中'")["value"],
        "employee_count": fetch_one("SELECT COUNT(*) AS value FROM employees WHERE employment_status = '在职'")["value"],
    }
    revenue_rows = fetch_all("SELECT * FROM v_monthly_room_revenue ORDER BY revenue_month DESC LIMIT 6")
    occupied_rooms = fetch_all("SELECT * FROM v_current_occupied_rooms ORDER BY checkin_time DESC LIMIT 6")
    return render_template("dashboard.html", stats=stats, revenue_rows=revenue_rows, occupied_rooms=occupied_rooms)


@app.route("/rooms", methods=["GET", "POST"])
@login_required
@permission_required("rooms")
def rooms():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "add":
                execute(
                    "INSERT INTO rooms (room_no, floor_no, room_type_id, remark) VALUES (%s, %s, %s, %s)",
                    (
                        request.form["room_no"].strip(),
                        request.form["floor_no"],
                        request.form["room_type_id"],
                        request.form.get("remark") or None,
                    ),
                )
                flash("客房新增成功。", "success")
            elif action == "status":
                execute(
                    "UPDATE rooms SET room_status = %s WHERE room_id = %s",
                    (request.form["room_status"], request.form["room_id"]),
                )
                flash("客房状态已更新。", "success")
            elif action == "delete":
                execute("DELETE FROM rooms WHERE room_id = %s", (request.form["room_id"],))
                flash("客房删除成功。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("rooms"))

    rows = fetch_all(
        """
        SELECT r.room_id, r.room_no, r.floor_no, rt.type_name, rt.standard_price, r.room_status, r.remark
        FROM rooms r
        JOIN room_types rt ON r.room_type_id = rt.room_type_id
        ORDER BY r.floor_no, r.room_no
        """
    )
    room_types = fetch_all("SELECT room_type_id, type_name, standard_price FROM room_types ORDER BY room_type_id")
    return render_template("rooms.html", rows=rows, room_types=room_types)


@app.route("/customers", methods=["GET", "POST"])
@login_required
@permission_required("customers")
def customers():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "add":
                execute(
                    """
                    INSERT INTO customers (customer_name, id_card, phone, member_level)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (
                        request.form["customer_name"].strip(),
                        request.form["id_card"].strip(),
                        request.form["phone"].strip(),
                        request.form["member_level"],
                    ),
                )
                flash("客户新增成功。", "success")
            elif action == "update":
                execute(
                    "UPDATE customers SET phone = %s, member_level = %s WHERE customer_id = %s",
                    (request.form["phone"].strip(), request.form["member_level"], request.form["customer_id"]),
                )
                flash("客户信息已更新。", "success")
            elif action == "delete":
                execute("DELETE FROM customers WHERE customer_id = %s", (request.form["customer_id"],))
                flash("客户删除成功。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("customers"))

    rows = fetch_all("SELECT * FROM customers ORDER BY customer_id")
    return render_template("customers.html", rows=rows)


@app.route("/employees", methods=["GET", "POST"])
@login_required
@permission_required("employees")
def employees():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "add":
                call_proc(
                    "sp_add_employee",
                    [
                        request.form["employee_no"].strip(),
                        request.form["employee_name"].strip(),
                        request.form["gender"],
                        int(request.form["department_id"]),
                        int(request.form["position_id"]),
                        request.form["phone"].strip(),
                        request.form["id_card"].strip(),
                        request.form["hire_date"],
                        float(request.form["base_salary"]),
                        int(request.form["role_id"]),
                        request.form["username"].strip(),
                        sha256_text(request.form["password"].strip()),
                    ],
                )
                flash("员工档案和登录账号已创建。", "success")
            elif action == "leave":
                execute(
                    """
                    UPDATE employees
                    SET employment_status = '离职', leave_date = %s
                    WHERE employee_id = %s
                    """,
                    (request.form["leave_date"], request.form["employee_id"]),
                )
                flash("员工已离职，触发器会自动锁定账号。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("employees"))

    rows = fetch_all(
        """
        SELECT e.employee_id, e.employee_no, e.employee_name, e.gender,
               d.department_name, p.position_name, e.phone,
               e.hire_date, e.leave_date, e.employment_status, e.base_salary
        FROM employees e
        JOIN departments d ON e.department_id = d.department_id
        JOIN positions p ON e.position_id = p.position_id
        ORDER BY e.employee_id
        """
    )
    departments = fetch_all("SELECT department_id, department_name FROM departments ORDER BY department_id")
    positions = fetch_all("SELECT position_id, position_name, department_id FROM positions ORDER BY position_id")
    roles = fetch_all("SELECT role_id, role_name FROM roles ORDER BY role_id")
    return render_template("employees.html", rows=rows, departments=departments, positions=positions, roles=roles)


@app.route("/checkin", methods=["GET", "POST"])
@login_required
@permission_required("checkin")
def checkin():
    if request.method == "POST":
        try:
            call_proc(
                "sp_checkin",
                [
                    request.form["order_no"].strip(),
                    int(request.form["customer_id"]),
                    int(request.form["room_id"]),
                    int(request.form["receptionist_id"]),
                    request.form["expected_checkout_time"],
                    float(request.form["room_price"]),
                    float(request.form["deposit_amount"]),
                ],
            )
            flash("入住办理成功。", "success")
            return redirect(url_for("reports", tab="occupied"))
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")

    customers = fetch_all("SELECT customer_id, customer_name, phone FROM customers ORDER BY customer_id")
    rooms = fetch_all(
        """
        SELECT r.room_id, r.room_no, rt.type_name, rt.standard_price
        FROM rooms r
        JOIN room_types rt ON r.room_type_id = rt.room_type_id
        WHERE r.room_status = '空闲'
        ORDER BY r.room_no
        """
    )
    receptionists = fetch_all(
        """
        SELECT e.employee_id, e.employee_name, e.employee_no
        FROM employees e
        JOIN departments d ON e.department_id = d.department_id
        WHERE d.department_name = '前厅部' AND e.employment_status = '在职'
        ORDER BY e.employee_id
        """
    )
    suggested_order_no = "ORD" + datetime.now().strftime("%Y%m%d%H%M%S")
    return render_template(
        "checkin.html",
        customers=customers,
        rooms=rooms,
        receptionists=receptionists,
        suggested_order_no=suggested_order_no,
    )


@app.route("/checkout", methods=["GET", "POST"])
@login_required
@permission_required("checkout")
def checkout():
    if request.method == "POST":
        try:
            call_proc("sp_checkout", [int(request.form["order_id"]), int(current_user()["employee_id"])])
            flash("退房结算成功，客房状态已自动改为待打扫。", "success")
            return redirect(url_for("reports", tab="revenue"))
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")

    orders = fetch_all(
        """
        SELECT co.order_id, co.order_no, c.customer_name, r.room_no, co.checkin_time, co.deposit_amount
        FROM checkin_orders co
        JOIN customers c ON co.customer_id = c.customer_id
        JOIN rooms r ON co.room_id = r.room_id
        WHERE co.order_status = '入住中'
        ORDER BY co.checkin_time DESC
        """
    )
    return render_template("checkout.html", orders=orders)


@app.route("/attendance", methods=["GET", "POST"])
@login_required
@permission_required("attendance")
def attendance():
    if request.method == "POST":
        try:
            execute(
                """
                INSERT INTO attendance_records (
                  employee_id, attendance_date, check_in_time, check_out_time, attendance_status
                ) VALUES (%s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                  check_in_time = VALUES(check_in_time),
                  check_out_time = VALUES(check_out_time),
                  attendance_status = VALUES(attendance_status)
                """,
                (
                    request.form["employee_id"],
                    request.form["attendance_date"],
                    request.form.get("check_in_time") or None,
                    request.form.get("check_out_time") or None,
                    request.form["attendance_status"],
                ),
            )
            flash("考勤记录已保存。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("attendance"))

    employees_rows = fetch_all(
        "SELECT employee_id, employee_no, employee_name FROM employees WHERE employment_status = '在职' ORDER BY employee_id"
    )
    rows = fetch_all(
        """
        SELECT ar.attendance_id, e.employee_no, e.employee_name, ar.attendance_date,
               ar.check_in_time, ar.check_out_time, ar.attendance_status
        FROM attendance_records ar
        JOIN employees e ON ar.employee_id = e.employee_id
        ORDER BY ar.attendance_date DESC, e.employee_no
        LIMIT 100
        """
    )
    return render_template("attendance.html", employees=employees_rows, rows=rows)


@app.route("/salary", methods=["GET", "POST"])
@login_required
@permission_required("salary")
def salary():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "generate":
                call_proc("sp_calculate_monthly_salary", [request.form["salary_month"]])
                flash("月度薪资已生成或更新。", "success")
            elif action == "pay":
                call_proc("sp_pay_salary", [int(request.form["salary_id"]), int(current_user()["employee_id"])])
                flash("发薪成功。", "success")
        except mysql.connector.Error as error:
            flash(handle_db_error(error), "error")
        return redirect(url_for("salary"))

    rows = fetch_all(
        """
        SELECT sr.salary_id, sr.salary_month, e.employee_no, e.employee_name,
               sr.base_salary, sr.cleaning_bonus, sr.reception_bonus, sr.repair_bonus,
               sr.overtime_pay, sr.attendance_deduction, sr.actual_salary,
               COALESCE(sp.payment_status, '未发放') AS payment_status, sp.paid_at
        FROM salary_records sr
        JOIN employees e ON sr.employee_id = e.employee_id
        LEFT JOIN salary_payments sp ON sr.salary_id = sp.salary_id
        ORDER BY sr.salary_month DESC, e.employee_no
        """
    )
    return render_template("salary.html", rows=rows, default_month=datetime.now().strftime("%Y-%m"))


@app.route("/reports")
@login_required
@permission_required("reports")
def reports():
    data = {
        "occupied": fetch_all("SELECT * FROM v_current_occupied_rooms ORDER BY checkin_time DESC"),
        "revenue": fetch_all("SELECT * FROM v_monthly_room_revenue ORDER BY revenue_month DESC"),
        "attendance": fetch_all(
            "SELECT * FROM v_employee_monthly_attendance_summary ORDER BY attendance_month DESC, employee_id"
        ),
        "salary": fetch_all(
            """
            SELECT sr.salary_month, e.employee_no, e.employee_name, sr.base_salary,
                   sr.cleaning_bonus, sr.reception_bonus, sr.repair_bonus,
                   sr.overtime_pay, sr.attendance_deduction, sr.actual_salary
            FROM salary_records sr
            JOIN employees e ON sr.employee_id = e.employee_id
            ORDER BY sr.salary_month DESC, e.employee_no
            """
        ),
    }
    return render_template("reports.html", data=data, tab=request.args.get("tab", "occupied"))


@app.route("/export/<name>")
@login_required
@permission_required("export")
def export_csv(name):
    queries = {
        "customers": ("客户数据", "SELECT * FROM customers"),
        "rooms": ("客房数据", "SELECT * FROM rooms"),
        "employees": ("员工数据", "SELECT * FROM employees"),
        "salary": ("薪资数据", "SELECT * FROM salary_records"),
        "revenue": ("月度营收", "SELECT * FROM v_monthly_room_revenue"),
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


@app.route("/codes")
@login_required
def codes():
    data = {
        "departments": fetch_all("SELECT department_id, department_name FROM departments ORDER BY department_id"),
        "positions": fetch_all("SELECT position_id, position_name, department_id FROM positions ORDER BY position_id"),
        "roles": fetch_all("SELECT role_id, role_code, role_name FROM roles ORDER BY role_id"),
        "rooms": fetch_all("SELECT room_id, room_no, room_status FROM rooms ORDER BY room_no"),
        "customers": fetch_all("SELECT customer_id, customer_name, phone FROM customers ORDER BY customer_id"),
        "employees": fetch_all("SELECT employee_id, employee_no, employee_name FROM employees ORDER BY employee_id"),
    }
    return render_template("codes.html", data=data)


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001, debug=True)
