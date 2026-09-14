"""
医院门诊管理系统 —— 环境自检脚本

用途：运行前检查四件事：
  1. Python 版本是否满足要求；
  2. Python 依赖（mysql-connector-python / flask）是否安装；
  3. MySQL 是否可达（host/port/user/password 是否正确）；
  4. hospital_outpatient 数据库是否已初始化（表数量、账号数量）。

用法：
    python check_env.py
    python check_env.py --user root --password 你的密码

提示：
    - 若第 3、4 项失败，先安装/启动 MySQL，再运行 init_database.py 初始化。
"""

import argparse
import os
import sys
from pathlib import Path

REQUIRED_PYTHON = (3, 8)
SQL_FILES = [
    "01_create_database.sql",
    "02_create_tables.sql",
    "03_views.sql",
    "04_procedures.sql",
    "05_triggers.sql",
    "06_indexes_queries.sql",
    "07_seed_data.sql",
]


def default_config():
    return {
        "host": os.getenv("HOTEL_DB_HOST", "127.0.0.1"),
        "port": int(os.getenv("HOTEL_DB_PORT", "3306")),
        "user": os.getenv("HOTEL_DB_USER", "root"),
        "password": os.getenv("HOTEL_DB_PASSWORD", "123456"),
        "charset": "utf8mb4",
        "use_unicode": True,
    }


def check_python():
    print("\n[1/4] Python 版本")
    print(f"  当前：{sys.version.split()[0]}")
    if sys.version_info >= REQUIRED_PYTHON:
        print("  [OK] 满足要求（>= 3.8）")
        return True
    print("  [失败] 版本过低，请安装 Python 3.8 及以上版本")
    return False


def check_dependencies():
    print("\n[2/4] Python 依赖")
    ok = True
    for package in ("mysql.connector", "flask"):
        try:
            module = __import__(package)
            try:
                from importlib.metadata import version

                version = version(package.replace("mysql.connector", "mysql-connector-python"))
            except Exception:
                version = "已安装"
            print(f"  {package}: {version}  [OK]")
        except ImportError:
            print(f"  {package}: 未安装  [失败]")
            ok = False
    if not ok:
        print("  提示：执行 python -m pip install -r requirements.txt 安装依赖")
    return ok


def check_mysql(config):
    print("\n[3/4] MySQL 连接")
    try:
        import mysql.connector
    except ImportError:
        print("  [跳过] 缺少 mysql-connector-python，无法检测")
        return False
    try:
        conn = mysql.connector.connect(**config)
        conn.close()
        print(f"  [OK] 已连接 {config['user']}@{config['host']}:{config['port']}")
        return True
    except mysql.connector.Error as exc:
        print(f"  [失败] {exc}")
        print("  提示：请确认 MySQL 已安装并启动（服务名通常为 MySQL80），")
        print("        用户名/密码/端口是否正确（默认 root / 123456 / 3306）。")
        return False


def check_database(config):
    print("\n[4/4] 数据库初始化状态")
    try:
        import mysql.connector
    except ImportError:
        return False
    try:
        conn = mysql.connector.connect(**config)
        cursor = conn.cursor()
        cursor.execute("SHOW DATABASES LIKE 'hospital_outpatient'")
        if not cursor.fetchone():
            print("  [失败] 数据库 hospital_outpatient 不存在，尚未初始化")
            print("  提示：运行 python init_database.py 一键初始化")
            cursor.close()
            conn.close()
            return False
        cursor.execute("USE hospital_outpatient")
        cursor.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'hospital_outpatient'")
        table_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM employees")
        employee_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM user_accounts")
        account_count = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        print(f"  [OK] 数据库 hospital_outpatient 已存在")
        print(f"       数据表数量：{table_count}")
        print(f"       员工数量：{employee_count}，登录账号数量：{account_count}")
        if table_count < 12:
            print("  [警告] 表数量偏少，可能初始化不完整，建议重新执行 init_database.py")
        return True
    except mysql.connector.Error as exc:
        print(f"  [失败] {exc}")
        return False


def main():
    parser = argparse.ArgumentParser(description="医院门诊管理系统：环境自检")
    parser.add_argument("--host", default=None)
    parser.add_argument("--port", type=int, default=None)
    parser.add_argument("--user", default=None)
    parser.add_argument("--password", default=None)
    args = parser.parse_args()

    config = default_config()
    if args.host:
        config["host"] = args.host
    if args.port:
        config["port"] = args.port
    if args.user:
        config["user"] = args.user
    if args.password:
        config["password"] = args.password

    print("=" * 60)
    print("医院门诊管理系统 —— 环境自检")
    print("=" * 60)

    py_ok = check_python()
    dep_ok = check_dependencies()
    mysql_ok = check_mysql(config) if dep_ok else False
    db_ok = check_database(config) if mysql_ok else False

    print("\n" + "=" * 60)
    if py_ok and dep_ok and mysql_ok and db_ok:
        print("全部检查通过，可以直接运行系统：")
        print("  命令行版：cd python && python app.py")
        print("  Web 版：  cd web_app && python app.py  然后浏览器打开 http://127.0.0.1:5000")
    else:
        print("存在未通过项，请按上面提示处理后重试。")
        if not mysql_ok:
            print("  → 先安装/启动 MySQL，再用 init_database.py 初始化数据库")
    print("=" * 60)


if __name__ == "__main__":
    main()
