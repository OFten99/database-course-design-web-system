"""
数据库连接配置。
在 PyCharm 中运行前，请先确认 MySQL 已执行 sql 文件夹中的脚本。
可直接修改 DEFAULT_CONFIG，也可以通过环境变量覆盖。
"""

import os
import mysql.connector


DEFAULT_CONFIG = {
    "host": os.getenv("HOTEL_DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("HOTEL_DB_PORT", "3306")),
    "user": os.getenv("HOTEL_DB_USER", "root"),
    "password": os.getenv("HOTEL_DB_PASSWORD", "123456"),
    "database": os.getenv("HOTEL_DB_NAME", "hotel_hr_system"),
    "charset": "utf8mb4",
    "use_unicode": True,
}


def get_connection():
    """创建数据库连接。"""
    return mysql.connector.connect(**DEFAULT_CONFIG)


def fetch_all(sql, params=None):
    """查询多行数据，返回字典列表。"""
    with get_connection() as conn:
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchall()


def fetch_one(sql, params=None):
    """查询单行数据，返回字典。"""
    with get_connection() as conn:
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchone()


def execute(sql, params=None):
    """执行增删改语句。"""
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql, params or ())
            conn.commit()
            return cursor.rowcount


def call_proc(proc_name, args):
    """调用 MySQL 存储过程。"""
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.callproc(proc_name, args)
            conn.commit()
