@echo off
chcp 65001 >nul
title 酒店人事一体化综合管理系统 - 命令行版
cd /d "%~dp0python"

echo ============================================================
echo   酒店人事一体化综合管理系统 - 命令行版
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
echo 正在启动，请在弹出的黑窗口中操作菜单...
python app.py

echo.
pause
