"""
医院门诊管理系统 Web 端数据库连接工具。
如果你的 MySQL 密码不是 123456，请修改 DEFAULT_CONFIG 或设置环境变量。
"""

import os
import mysql.connector


DEFAULT_CONFIG = {
    "host": os.getenv("HIS_DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("HIS_DB_PORT", "3306")),
    "user": os.getenv("HIS_DB_USER", "root"),
    "password": os.getenv("HIS_DB_PASSWORD", "123456"),
    "database": os.getenv("HIS_DB_NAME", "hospital_outpatient"),
    "charset": "utf8mb4",
    "use_unicode": True,
}


def get_connection():
    return mysql.connector.connect(**DEFAULT_CONFIG)


def fetch_all(sql, params=None):
    with get_connection() as conn:
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchall()


def fetch_one(sql, params=None):
    with get_connection() as conn:
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchone()


def execute(sql, params=None):
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql, params or ())
            conn.commit()
            return cursor.rowcount


def call_proc(proc_name, args):
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.callproc(proc_name, args)
            conn.commit()
