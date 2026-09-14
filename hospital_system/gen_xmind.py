# -*- coding: utf-8 -*-
"""
生成医院门诊管理系统 XMind 思维导图（.xmind 为 zip 包：content.json + metadata.json + manifest.json）。
"""
import json
import uuid
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

OUT = Path(__file__).resolve().parent / "docs" / "医院门诊管理系统需求分析.xmind"


def tid():
    return str(uuid.uuid4())


def topic(title, children=None, note=None):
    t = {"id": tid(), "title": title}
    if note:
        t["notes"] = {"plain": {"content": note}}
    if children:
        t["children"] = {"attached": children}
    return t


def sheet(title, root):
    return {
        "id": tid(),
        "class": "sheet",
        "title": title,
        "rootTopic": root,
    }


def build():
    root = topic("医院门诊管理系统（对标小型 HIS 门诊业务）", children=[
        topic("系统概述", children=[
            topic("建设目标：模拟医院门诊业务 Web 后台，覆盖挂号、就诊、处方、收费全流程"),
            topic("对标对象：小型 HIS 门诊子系统"),
            topic("使用者角色", children=[
                topic("管理员 ADMIN：系统管理、全部业务权限"),
                topic("医生 DOCTOR：查看挂号、开具处方、管理患者"),
                topic("挂号员 REGISTRAR：患者建档、挂号、退号"),
                topic("收费员 CASHIER：处方收费、退费、报表"),
            ]),
        ]),
        topic("功能性需求", children=[
            topic("患者档案管理：建档、查询、修改、删除（唯一约束：病历号/身份证/电话）"),
            topic("挂号管理：选择排班挂号、自动收挂号费、排队号、退号恢复号源"),
            topic("医生排班：按医生/日期/班次排班、号源管理、停诊保护（有挂号不可停诊）"),
            topic("处方开具：多药品明细、库存校验、金额自动计算、状态机（待收费→已收费→已退费/已作废）"),
            topic("收费退费：处方收费扣库存、退费恢复库存、退号联动退挂号费"),
            topic("药品目录：药品信息、价格、库存、启用/停用"),
            topic("报表查询：今日挂号统计、收费日报、处方明细、医生工作量"),
            topic("登录与权限：角色权限控制、操作日志"),
        ]),
        topic("数据库设计（MySQL）", children=[
            topic("12 张核心表", children=[
                topic("基础：roles / users / departments / doctors"),
                topic("业务：doctor_schedules / patients / registrations"),
                topic("处方：medicines / prescriptions / prescription_items"),
                topic("财务与日志：payments / operation_logs"),
            ]),
            topic("5 个视图：今日挂号、排班、处方明细、收费日报、医生工作量"),
            topic("7 个存储过程：新增用户/医生、挂号、退号、开方、收费、退费（全部事务）"),
            topic("4 个触发器：挂号/收费/建档自动写日志、排班停诊保护"),
            topic("索引：挂号、排班、处方、收费、日志高频查询字段"),
        ]),
        topic("核心业务流程", children=[
            topic("就诊主流程：患者建档 → 排班 → 挂号（收挂号费）→ 医生开方 → 收费（扣库存）→ 取药"),
            topic("退费流程：已收费处方 → 收费员退费 → 恢复库存 → 处方已退费"),
            topic("退号流程：待就诊挂号 → 退号 → 恢复号源 → 退回挂号费"),
            topic("状态机", children=[
                topic("挂号：待就诊 → 就诊中 → 已就诊 / 已退号"),
                topic("处方：待收费 → 已收费 → 已退费 / 已作废"),
                topic("收费：已收费 → 已退费"),
            ]),
        ]),
        topic("技术栈与工具", children=[
            topic("后端：Python 3.14 + Flask 3.1 + mysql-connector-python"),
            topic("数据库：MySQL 8.4（数据库 hospital_outpatient）"),
            topic("前端：Jinja2 模板 + CSS（HIS Web 管理端）"),
            topic("项目管理：禅道（需求、任务、测试用例、缺陷）"),
            topic("测试方法：黑盒测试（功能测试用例 50 条）"),
            topic("设计工具：XMind（本图）"),
        ]),
        topic("测试方案（黑盒测试）", children=[
            topic("测试范围：登录权限、患者、挂号、排班、处方、收费退费、报表导出、数据一致性"),
            topic("方法：等价类划分、边界值分析、错误推测法"),
            topic("测试用例：docs/黑盒测试用例_医院门诊管理系统.xlsx（50 条，禅道导入格式）"),
            topic("自动化冒烟：verify_hospital.py（登录→挂号→开方→收费→退费→退号回归）"),
            topic("关键校验点：号源守恒、库存守恒、状态机流转、触发器日志、事务回滚"),
        ]),
        topic("部署与运行", children=[
            topic("1. 启动 MySQL（start_mysql.bat，root/123456）"),
            topic("2. python init_database.py 初始化数据库"),
            topic("3. cd web_app && python app.py 启动 Web"),
            topic("4. 浏览器访问 http://127.0.0.1:5000"),
            topic("测试账号：admin01 / doctor01 / reg01 / cash01，密码 123456"),
        ]),
    ])

    content = [sheet("医院门诊管理系统需求分析", root)]
    metadata = {
        "creator": {"name": "Doubao Agent", "version": "1.0.0"},
    }
    manifest = [
        {"file-path": "content.json", "content": "content"},
        {"file-path": "metadata.json", "content": "metadata"},
    ]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(OUT, "w", ZIP_DEFLATED) as zf:
        zf.writestr("content.json", json.dumps(content, ensure_ascii=False, indent=2))
        zf.writestr("metadata.json", json.dumps(metadata, ensure_ascii=False, indent=2))
        zf.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False))
    print(f"已生成：{OUT}")


if __name__ == "__main__":
    build()
