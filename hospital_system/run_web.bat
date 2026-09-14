@echo off
chcp 65001 >nul
title 医院门诊管理系统 - Web 版
cd /d "%~dp0web_app"

echo ============================================================
echo   医院门诊管理系统（对标小型 HIS 门诊业务）- Web 版
echo ============================================================
echo.
echo 正在检查并安装依赖（首次运行需要联网）...
python -m pip install -r requirements.txt -q
if errorlevel 1 (
    echo [错误] 依赖安装失败，请检查网络后重试。
    pause
    exit /b 1
)

echo.
echo 提示：请先确认已执行过 init_database.py 初始化数据库。
echo       若还没有，请先运行 python init_database.py。
echo.
echo 启动成功后，请在浏览器打开：http://127.0.0.1:5000
echo 测试账号：admin01 / doctor01 / reg01 / cash01（密码均为 123456）
echo 请不要关闭本窗口，关闭即停止服务。
echo.
python app.py

echo.
pause
