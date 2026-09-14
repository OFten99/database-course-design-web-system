"""
酒店人事一体化综合管理系统简易交互程序。
功能：登录、客房/客户/员工管理、入住退房、考勤登记、薪资生成、报表查看、数据导出。
运行前请先在 DataGrip 中依次执行 sql 文件夹中的 01~07 脚本。
"""

import hashlib
import sys
from datetime import datetime
from pathlib import Path

import mysql.connector

from db import call_proc, execute, fetch_all, fetch_one, get_connection
from export_utils import export_rows_to_csv, print_rows


EXPORT_DIR = Path(__file__).resolve().parent / "exports"


def sha256_text(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def input_required(prompt):
    while True:
        value = input(prompt).strip()
        if value:
            return value
        print("输入不能为空，请重新输入。")


def input_int(prompt):
    while True:
        try:
            return int(input_required(prompt))
        except ValueError:
            print("请输入整数。")


def input_decimal(prompt):
    while True:
        try:
            return float(input_required(prompt))
        except ValueError:
            print("请输入数字。")


def pause():
    input("\n按回车继续...")


def login():
    print("=== 酒店人事一体化综合管理系统 ===")
    username = input_required("用户名：")
    password = input_required("密码：")
    password_hash = sha256_text(password)

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
        (username, password_hash),
    )

    if not user:
        print("用户名或密码错误。")
        return None
    if user["account_status"] != "启用":
        print("账号已被锁定，无法登录。")
        return None

    execute("UPDATE user_accounts SET last_login_at = NOW() WHERE account_id = %s", (user["account_id"],))
    print(f"登录成功：{user['employee_name']}（{user['role_name']}）")
    return user


def show_rooms():
    rows = fetch_all(
        """
        SELECT r.room_id, r.room_no, r.floor_no, rt.type_name, rt.standard_price, r.room_status, r.remark
        FROM rooms r
        JOIN room_types rt ON r.room_type_id = rt.room_type_id
        ORDER BY r.floor_no, r.room_no
        """
    )
    print_rows(rows)


def add_room():
    room_no = input_required("房号：")
    floor_no = input_int("楼层：")
    room_type_id = input_int("房型编号：")
    remark = input("备注：").strip() or None
    execute(
        "INSERT INTO rooms (room_no, floor_no, room_type_id, remark) VALUES (%s, %s, %s, %s)",
        (room_no, floor_no, room_type_id, remark),
    )
    print("客房新增成功。")


def update_room_status():
    room_id = input_int("客房编号：")
    status = input_required("新状态（空闲/入住/维修/待打扫）：")
    execute("UPDATE rooms SET room_status = %s WHERE room_id = %s", (status, room_id))
    print("客房状态已更新。")


def delete_room():
    room_id = input_int("要删除的客房编号：")
    execute("DELETE FROM rooms WHERE room_id = %s", (room_id,))
    print("客房删除成功。若有关联订单，数据库会阻止删除。")


def room_menu():
    while True:
        print("\n--- 客房管理 ---")
        print("1. 查询客房")
        print("2. 新增客房")
        print("3. 修改客房状态")
        print("4. 删除客房")
        print("0. 返回")
        choice = input_required("请选择：")
        if choice == "1":
            show_rooms()
        elif choice == "2":
            add_room()
        elif choice == "3":
            update_room_status()
        elif choice == "4":
            delete_room()
        elif choice == "0":
            return
        else:
            print("无效选项。")
        pause()


def show_customers():
    rows = fetch_all(
        """
        SELECT customer_id, customer_name, id_card, phone, member_level, points, created_at
        FROM customers
        ORDER BY customer_id
        """
    )
    print_rows(rows)


def add_customer():
    customer_name = input_required("客户姓名：")
    id_card = input_required("身份证号：")
    phone = input_required("联系电话：")
    member_level = input("会员等级（普通/银卡/金卡/钻石，默认普通）：").strip() or "普通"
    execute(
        """
        INSERT INTO customers (customer_name, id_card, phone, member_level)
        VALUES (%s, %s, %s, %s)
        """,
        (customer_name, id_card, phone, member_level),
    )
    print("客户新增成功。")


def update_customer():
    customer_id = input_int("客户编号：")
    phone = input_required("新联系电话：")
    member_level = input_required("新会员等级（普通/银卡/金卡/钻石）：")
    execute(
        "UPDATE customers SET phone = %s, member_level = %s WHERE customer_id = %s",
        (phone, member_level, customer_id),
    )
    print("客户信息已更新。")


def delete_customer():
    customer_id = input_int("要删除的客户编号：")
    execute("DELETE FROM customers WHERE customer_id = %s", (customer_id,))
    print("客户删除成功。若已有入住订单，数据库会阻止删除。")


def customer_menu():
    while True:
        print("\n--- 客户管理 ---")
        print("1. 查询客户")
        print("2. 新增客户")
        print("3. 修改客户")
        print("4. 删除客户")
        print("0. 返回")
        choice = input_required("请选择：")
        if choice == "1":
            show_customers()
        elif choice == "2":
            add_customer()
        elif choice == "3":
            update_customer()
        elif choice == "4":
            delete_customer()
        elif choice == "0":
            return
        else:
            print("无效选项。")
        pause()


def show_employees():
    rows = fetch_all(
        """
        SELECT
          e.employee_id, e.employee_no, e.employee_name, e.gender,
          d.department_name, p.position_name, e.phone,
          e.hire_date, e.leave_date, e.employment_status, e.base_salary
        FROM employees e
        JOIN departments d ON e.department_id = d.department_id
        JOIN positions p ON e.position_id = p.position_id
        ORDER BY e.employee_id
        """
    )
    print_rows(rows)


def add_employee():
    employee_no = input_required("工号：")
    employee_name = input_required("姓名：")
    gender = input_required("性别（男/女）：")
    department_id = input_int("部门编号：")
    position_id = input_int("岗位编号：")
    phone = input_required("联系电话：")
    id_card = input_required("证件号码：")
    hire_date = input_required("入职日期（YYYY-MM-DD）：")
    base_salary = input_decimal("基本工资：")
    role_id = input_int("角色编号：")
    username = input_required("登录用户名：")
    password = input_required("登录密码：")

    call_proc(
        "sp_add_employee",
        [
            employee_no,
            employee_name,
            gender,
            department_id,
            position_id,
            phone,
            id_card,
            hire_date,
            base_salary,
            role_id,
            username,
            sha256_text(password),
        ],
    )
    print("员工档案和账号已创建。")


def mark_employee_left():
    employee_id = input_int("离职员工编号：")
    leave_date = input_required("离职日期（YYYY-MM-DD）：")
    execute(
        """
        UPDATE employees
        SET employment_status = '离职', leave_date = %s
        WHERE employee_id = %s
        """,
        (leave_date, employee_id),
    )
    print("员工已标记离职，触发器会自动锁定账号。")


def employee_menu():
    while True:
        print("\n--- 员工管理 ---")
        print("1. 查询员工")
        print("2. 新增员工")
        print("3. 员工离职")
        print("0. 返回")
        choice = input_required("请选择：")
        if choice == "1":
            show_employees()
        elif choice == "2":
            add_employee()
        elif choice == "3":
            mark_employee_left()
        elif choice == "0":
            return
        else:
            print("无效选项。")
        pause()


def checkin():
    order_no = input_required("订单号：")
    customer_id = input_int("客户编号：")
    room_id = input_int("客房编号：")
    receptionist_id = input_int("前台员工编号：")
    expected_checkout_time = input_required("预计退房时间（YYYY-MM-DD HH:MM:SS）：")
    room_price = input_decimal("成交房价：")
    deposit_amount = input_decimal("押金金额：")
    call_proc(
        "sp_checkin",
        [
            order_no,
            customer_id,
            room_id,
            receptionist_id,
            expected_checkout_time,
            room_price,
            deposit_amount,
        ],
    )
    print("入住办理成功。")


def checkout(user):
    order_id = input_int("入住订单编号：")
    call_proc("sp_checkout", [order_id, user["employee_id"]])
    print("退房结算成功，客房状态会由触发器改为待打扫。")


def add_attendance():
    employee_id = input_int("员工编号：")
    attendance_date = input_required("考勤日期（YYYY-MM-DD）：")
    check_in_time = input("上班打卡时间（YYYY-MM-DD HH:MM:SS，可空）：").strip() or None
    check_out_time = input("下班打卡时间（YYYY-MM-DD HH:MM:SS，可空）：").strip() or None
    status = input_required("考勤状态（正常/迟到/早退/缺勤）：")
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
        (employee_id, attendance_date, check_in_time, check_out_time, status),
    )
    print("考勤记录已保存。")


def calculate_salary():
    salary_month = input_required("薪资月份（YYYY-MM）：")
    call_proc("sp_calculate_monthly_salary", [salary_month])
    print("月度薪资已生成或更新。")


def pay_salary(user):
    salary_id = input_int("薪资记录编号：")
    call_proc("sp_pay_salary", [salary_id, user["employee_id"]])
    print("发薪成功。")


def show_report():
    while True:
        print("\n--- 报表查询 ---")
        print("1. 当前占用客房")
        print("2. 月度客房营收")
        print("3. 员工月度考勤汇总")
        print("4. 薪资汇总")
        print("0. 返回")
        choice = input_required("请选择：")
        if choice == "1":
            print_rows(fetch_all("SELECT * FROM v_current_occupied_rooms"))
        elif choice == "2":
            print_rows(fetch_all("SELECT * FROM v_monthly_room_revenue ORDER BY revenue_month DESC"))
        elif choice == "3":
            print_rows(fetch_all("SELECT * FROM v_employee_monthly_attendance_summary ORDER BY attendance_month DESC, employee_id"))
        elif choice == "4":
            print_rows(
                fetch_all(
                    """
                    SELECT sr.salary_id, sr.salary_month, e.employee_no, e.employee_name,
                           sr.base_salary, sr.cleaning_bonus, sr.reception_bonus,
                           sr.repair_bonus, sr.overtime_pay, sr.attendance_deduction,
                           sr.actual_salary
                    FROM salary_records sr
                    JOIN employees e ON sr.employee_id = e.employee_id
                    ORDER BY sr.salary_month DESC, e.employee_no
                    """
                )
            )
        elif choice == "0":
            return
        else:
            print("无效选项。")
        pause()


def export_data():
    tables = {
        "1": ("customers", "客户数据", "SELECT * FROM customers"),
        "2": ("rooms", "客房数据", "SELECT * FROM rooms"),
        "3": ("employees", "员工数据", "SELECT * FROM employees"),
        "4": ("salary_records", "薪资数据", "SELECT * FROM salary_records"),
        "5": ("monthly_revenue", "月度营收", "SELECT * FROM v_monthly_room_revenue"),
    }
    print("\n--- 数据导出 ---")
    for key, (_, name, _) in tables.items():
        print(f"{key}. {name}")
    choice = input_required("请选择导出内容：")
    if choice not in tables:
        print("无效选项。")
        return

    file_prefix, _, sql = tables[choice]
    rows = fetch_all(sql)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = EXPORT_DIR / f"{file_prefix}_{timestamp}.csv"
    export_rows_to_csv(rows, output_path)
    print(f"导出完成：{output_path}")


def show_basic_codes():
    print("\n--- 基础编号参考 ---")
    print("部门：")
    print_rows(fetch_all("SELECT department_id, department_name FROM departments ORDER BY department_id"))
    print("\n岗位：")
    print_rows(fetch_all("SELECT position_id, position_name, department_id FROM positions ORDER BY position_id"))
    print("\n角色：")
    print_rows(fetch_all("SELECT role_id, role_code, role_name FROM roles ORDER BY role_id"))


def can_access(user, menu_key):
    role = user["role_code"]
    if role == "MANAGER":
        return True
    permissions = {
        "FRONT_DESK": {"1", "2", "4", "6", "8", "9"},
        "HR": {"1", "3", "5", "8", "9", "10"},
        "FINANCE": {"7", "8", "9", "10"},
    }
    return menu_key in permissions.get(role, set())


def main_menu(user):
    while True:
        print("\n=== 主菜单 ===")
        print("1. 客房管理")
        print("2. 客户管理")
        print("3. 员工管理")
        print("4. 办理入住")
        print("5. 考勤登记")
        print("6. 退房结算")
        print("7. 薪资核算与发放")
        print("8. 报表查询")
        print("9. 数据导出")
        print("10. 基础编号参考")
        print("0. 退出")
        choice = input_required("请选择：")

        if choice == "0":
            print("系统已退出。")
            return
        if not can_access(user, choice):
            print("当前角色无权执行该功能。")
            pause()
            continue

        try:
            if choice == "1":
                room_menu()
            elif choice == "2":
                customer_menu()
            elif choice == "3":
                employee_menu()
            elif choice == "4":
                checkin()
            elif choice == "5":
                add_attendance()
            elif choice == "6":
                checkout(user)
            elif choice == "7":
                print("1. 生成月度薪资")
                print("2. 发放薪资")
                salary_choice = input_required("请选择：")
                if salary_choice == "1":
                    calculate_salary()
                elif salary_choice == "2":
                    pay_salary(user)
                else:
                    print("无效选项。")
            elif choice == "8":
                show_report()
            elif choice == "9":
                export_data()
            elif choice == "10":
                show_basic_codes()
            else:
                print("无效选项。")
        except mysql.connector.Error as exc:
            print(f"数据库操作失败：{exc}")
        except KeyboardInterrupt:
            print("\n操作已取消。")
        pause()


def check_database_connection():
    try:
        with get_connection() as conn:
            return conn.is_connected()
    except mysql.connector.Error as exc:
        print("无法连接数据库，请检查 db.py 中的 MySQL 配置。")
        print(f"错误信息：{exc}")
        return False


def main():
    if not check_database_connection():
        sys.exit(1)

    user = login()
    if user:
        main_menu(user)


if __name__ == "__main__":
    main()
