# 数据库开发课程设计 — 综合管理 Web 系统（酒店人事一体化管理系统）

基于 **Python Flask + MySQL** 的综合管理系统课程设计项目：**酒店人事一体化综合管理系统**（客房管理、入住退房、员工考勤、薪资核算、报表中心）。

> 🏥 医院门诊管理系统（对标小型 HIS 门诊业务）已独立迁移至单独仓库：**[OFten99/hospital-system](https://github.com/OFten99/hospital-system)**

---

## ✨ 功能特性

- **客房管理**：房态总览、房间维护
- **前台业务**：客户档案、入住登记、退房结算
- **人事管理**：员工档案、考勤记录、请假管理、薪资核算
- **报表中心**：入住统计、收入报表、员工考勤汇总
- **权限控制**：前台 / 人事 / 财务 / 经理多角色

---

## 🛠 技术栈

- **后端**：Python 3.14 + Flask 3.1 + mysql-connector-python
- **数据库**：MySQL 8.4（存储过程 / 视图 / 触发器 / 事务 / 索引）
- **前端**：Jinja2 模板 + 原生 CSS（深色侧栏 + 卡片式管理端布局）
- **工程化**：一键初始化脚本、环境自检脚本、端到端回归验证脚本

---

## 📁 目录结构

```
├── hotel system/               # 酒店系统脚本与说明（init_database、run_web、start_mysql 等）
├── sql/                        # 酒店系统数据库脚本（01 建库 ~ 07 测试数据）
├── python/                     # 酒店系统命令行版
├── web_app/                    # 酒店系统 Web 版（Flask）
├── app-user-manual/            # 客户端使用说明书
├── README.md                   # 项目说明（本文件）
└── .gitignore                  # 忽略规则
```

---

## 🚀 快速开始

### 环境要求
- Python 3.10+（`python` 在 PATH 中）
- MySQL 8.x（本机免服务方式，数据目录 `D:\MySQLData`）

### 1. 启动 MySQL
双击 `start_mysql.bat`（Windows），或手动启动 MySQL 服务。默认连接：`root / 123456 / 127.0.0.1:3306`。

### 2. 初始化数据库
```bash
cd "hotel system" && python init_database.py
```

### 3. 启动 Web
```bash
cd web_app && python -m pip install -r requirements.txt && python app.py
```

浏览器访问：http://127.0.0.1:5001

### 测试账号（密码均为 `123456`）
| 账号 | 角色 |
| --- | --- |
| front01 | 前台 |
| room01 | 人事/客房 |
| finance01 | 财务 |
| manager01 | 经理（演示中被锁定） |

---

## 🧪 测试与验证

- **环境自检**：`python check_env.py`（检查 Python 依赖、MySQL 连接、数据库状态）
- **端到端回归**：`cd "hotel system" && python verify_hotel.py`

---

## 📄 许可证

本项目为课程设计学习项目，遵循 MIT License，仅供学习交流使用。

> ⚠️ 数据库默认密码 `123456` 为本地开发配置，生产环境请务必修改。
