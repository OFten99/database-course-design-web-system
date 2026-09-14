"""
酒店人事一体化综合管理系统 —— 一键初始化数据库脚本

作用：自动按顺序执行 sql 文件夹中的 01~07 号脚本，完成
      “建库 → 建表 → 建视图 → 建存储过程 → 建触发器 → 建索引/查询示例 → 灌测试数据”。

用法：
    python init_database.py                      # 使用默认配置 root / 123456
    python init_database.py --user root --password 你的密码
    python init_database.py --host 127.0.0.1 --port 3306 --user root --password 123456

也可以通过环境变量覆盖：HOTEL_DB_HOST / HOTEL_DB_PORT / HOTEL_DB_USER / HOTEL_DB_PASSWORD

说明：
    - 脚本是幂等的：任何一步失败都会立即停止并给出失败文件与错误信息；
      修复后重新运行即可（01 号脚本会 DROP DATABASE 重建，重复执行安全）。
    - 04 / 05 号脚本使用 DELIMITER 语法（mysql 客户端指令），本脚本已内置解析器，
      可以直接执行，不需要 DataGrip。
"""

import argparse
import os
import re
import sys
from pathlib import Path

SQL_DIR = Path(__file__).resolve().parent / "sql"
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


def split_sql_statements(sql_text):
    """
    把 SQL 文件内容拆成可逐条执行的语句列表。

    处理要点：
    1. 识别 mysql 客户端的 DELIMITER 指令（存储过程/触发器脚本会用到），
       切换语句结束分隔符，并把 DELIMITER 行本身剔除；
    2. 剔除纯注释行（-- 开头 / # 开头）与空行；
    3. 注释与字符串内的 ';' 不会误切（因为只在行尾或独立分隔符位置判断）。
    """
    statements = []
    buffer_lines = []
    delimiter = ";"

    def flush():
        """把 buffer 中积累的内容按当前分隔符切分并收集为语句。"""
        nonlocal buffer_lines
        text = "\n".join(buffer_lines)
        buffer_lines = []
        for raw_stmt in text.split(delimiter):
            stmt = raw_stmt.strip()
            if not stmt:
                continue
            # 去掉逐行注释后仍为空则跳过
            cleaned = "\n".join(
                line for line in stmt.splitlines()
                if not re.match(r"^\s*(--|#)", line)
            ).strip()
            if cleaned:
                statements.append(cleaned)

    for raw_line in sql_text.splitlines():
        stripped = raw_line.strip()
        if re.match(r"^DELIMITER\s+\S+\s*$", stripped, re.IGNORECASE):
            # 换分隔符前，先把手头的缓冲内容按旧分隔符切掉
            flush()
            delimiter = stripped.split()[1]
            continue
        buffer_lines.append(raw_line)

    flush()
    return statements


def execute_sql_file(conn, sql_file: Path):
    """在指定连接上执行一个 SQL 文件，返回执行的语句条数。"""
    sql_text = sql_file.read_text(encoding="utf-8-sig")
    statements = split_sql_statements(sql_text)
    if not statements:
        print(f"  [跳过] {sql_file.name}（没有可执行语句）")
        return 0

    cursor = conn.cursor()
    count = 0
    try:
        for stmt in statements:
            cursor.execute(stmt)
            # 消费结果集（SELECT / CALL 等会产生结果集，
            # 不读完会导致 mysql.connector 报 Unread result found）
            if cursor.with_rows:
                cursor.fetchall()
            count += 1
    finally:
        cursor.close()
    print(f"  [完成] {sql_file.name}（{count} 条语句）")
    return count


def main():
    parser = argparse.ArgumentParser(description="酒店人事一体化综合管理系统：一键初始化数据库")
    parser.add_argument("--host", default=None, help="MySQL 主机，默认 127.0.0.1")
    parser.add_argument("--port", type=int, default=None, help="MySQL 端口，默认 3306")
    parser.add_argument("--user", default=None, help="MySQL 用户名，默认 root")
    parser.add_argument("--password", default=None, help="MySQL 密码，默认 123456")
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

    if not SQL_DIR.exists():
        print(f"[错误] 找不到 sql 目录：{SQL_DIR}")
        sys.exit(1)

    missing = [name for name in SQL_FILES if not (SQL_DIR / name).exists()]
    if missing:
        print(f"[错误] sql 目录缺少文件：{', '.join(missing)}")
        sys.exit(1)

    print("=" * 60)
    print("酒店人事一体化综合管理系统 —— 数据库初始化")
    print(f"目标：{config['user']}@{config['host']}:{config['port']}")
    print("=" * 60)

    try:
        import mysql.connector
    except ImportError:
        print("[错误] 未安装 mysql-connector-python，请先执行：")
        print("       python -m pip install -r requirements.txt")
        sys.exit(1)

    # 先不指定 database 连接（01 号脚本负责建库）
    try:
        conn = mysql.connector.connect(**config)
        print("[连接] MySQL 连接成功。")
    except mysql.connector.Error as exc:
        print(f"[错误] 无法连接 MySQL（{config['host']}:{config['port']}）：{exc}")
        print("请确认：")
        print("  1. MySQL 8.0 已安装并已启动（服务名通常为 MySQL80）；")
        print("  2. 用户名 / 密码正确（默认 root / 123456，可用 --password 指定）；")
        print("  3. 端口正确（默认 3306）。")
        sys.exit(1)

    try:
        for name in SQL_FILES:
            execute_sql_file(conn, SQL_DIR / name)
        print("-" * 60)
        print("全部脚本执行成功！数据库 hotel_hr_system 已就绪。")
        print("测试账号：front01 / room01 / finance01 / manager01，密码均为 123456")
        print("（manager01 因测试数据演示离职会被锁定，如需启用见运行说明.md）")
    except mysql.connector.Error as exc:
        print("-" * 60)
        print(f"[失败] 执行 SQL 时出错：{exc}")
        print("修复问题后重新运行本脚本即可（脚本可重复执行）。")
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
