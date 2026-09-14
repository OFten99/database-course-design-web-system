"""
基础数据导出工具。
把查询结果导出为 CSV，便于作为课程设计运行截图和测试结果材料。
"""

import csv
from pathlib import Path


def export_rows_to_csv(rows, output_path):
    """把字典列表导出为 CSV 文件。"""
    output_file = Path(output_path)
    output_file.parent.mkdir(parents=True, exist_ok=True)

    if not rows:
        output_file.write_text("暂无数据\n", encoding="utf-8-sig")
        return output_file

    fieldnames = list(rows[0].keys())
    with output_file.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    return output_file


def print_rows(rows):
    """在命令行中以简单表格形式显示查询结果。"""
    if not rows:
        print("暂无数据")
        return

    headers = list(rows[0].keys())
    widths = {
        header: max(len(str(header)), *(len(str(row.get(header, ""))) for row in rows))
        for header in headers
    }

    line = " | ".join(str(header).ljust(widths[header]) for header in headers)
    print(line)
    print("-" * len(line))

    for row in rows:
        print(" | ".join(str(row.get(header, "")).ljust(widths[header]) for header in headers))
