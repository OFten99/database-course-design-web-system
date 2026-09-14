@echo off
chcp 65001 >nul
title 启动 MySQL（数据目录 D:\MySQLData）

echo ============================================================
echo   启动 MySQL 8.4（免服务方式，数据目录 D:\MySQLData）
echo ============================================================

netstat -ano | findstr ":3306" | findstr "LISTENING" >nul
if not errorlevel 1 (
    echo.
    echo [提示] MySQL 已在运行（3306 端口已监听），无需重复启动。
    pause
    exit /b 0
)

echo.
echo 正在启动 MySQL，请稍候...
start "" "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqld.exe" --no-defaults "--basedir=C:\Program Files\MySQL\MySQL Server 8.4" --datadir=D:\MySQLData --port=3306 --character-set-server=utf8mb4 --max_connections=200

timeout /t 6 /nobreak >nul

netstat -ano | findstr ":3306" | findstr "LISTENING" >nul
if errorlevel 1 (
    echo.
    echo [错误] MySQL 未能在 6 秒内就绪，请检查 D:\MySQLData 是否正常。
) else (
    echo.
    echo [OK] MySQL 已就绪（端口 3306，root 密码 123456）。
)
echo.
pause
