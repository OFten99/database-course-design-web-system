@echo off
chcp 65001 >nul
title MySQL 服务一键配置（请以管理员身份运行）

:: ============================================================
::  MySQL Server 8.4 服务一键配置脚本
::  功能：初始化数据目录 -> 创建服务 MySQL84 -> 启动服务
::        -> 设置 root 密码为 123456 -> 验证
::  用法：右键本文件 -> 以管理员身份运行
:: ============================================================

net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo [错误] 请右键本文件，选择"以管理员身份运行"。
    echo.
    pause
    exit /b 1
)

set "MYSQL_HOME=C:\Program Files\MySQL\MySQL Server 8.4"
set "MYSQL_BIN=%MYSQL_HOME%\bin"
set "DATA_DIR=C:\ProgramData\MySQL\MySQL Server 8.4\Data"
set "MY_INI=%MYSQL_HOME%\my.ini"
set "MYSQL_PASSWORD=123456"

echo ============================================================
echo  MySQL Server 8.4 服务配置
echo ============================================================
echo.

:: ---------- 1. 生成 my.ini 配置文件 ----------
if not exist "%MY_INI%" (
    echo [1/5] 生成配置文件 my.ini ...
    (
        echo [mysqld]
        echo basedir=C:/Program Files/MySQL/MySQL Server 8.4
        echo datadir=C:/ProgramData/MySQL/MySQL Server 8.4/Data
        echo port=3306
        echo character-set-server=utf8mb4
        echo default-storage-engine=INNODB
        echo max_connections=200
        echo [client]
        echo port=3306
        echo default-character-set=utf8mb4
    ) > "%MY_INI%"
) else (
    echo [1/5] 配置文件已存在，跳过。
)

:: ---------- 2. 初始化数据目录 ----------
if not exist "%DATA_DIR%\mysql" (
    echo [2/5] 初始化数据目录（首次运行，root 初始无密码）...
    "%MYSQL_BIN%\mysqld.exe" --defaults-file="%MY_INI%" --initialize-insecure
    if errorlevel 1 (
        echo.
        echo [错误] 数据目录初始化失败，请截图本窗口信息反馈。
        pause
        exit /b 1
    )
) else (
    echo [2/5] 数据目录已初始化，跳过。
)

:: ---------- 3. 创建 Windows 服务 ----------
sc query MySQL84 >nul 2>&1
if errorlevel 1 (
    echo [3/5] 创建 Windows 服务 MySQL84 ...
    "%MYSQL_BIN%\mysqld.exe" --install MySQL84 --defaults-file="%MY_INI%"
    if errorlevel 1 (
        echo.
        echo [错误] 服务创建失败，请确认已以管理员身份运行。
        pause
        exit /b 1
    )
) else (
    echo [3/5] 服务 MySQL84 已存在，跳过。
)

:: ---------- 4. 启动服务 ----------
sc query MySQL84 | find "RUNNING" >nul
if errorlevel 1 (
    echo [4/5] 启动服务 MySQL84 ...
    net start MySQL84
    if errorlevel 1 (
        echo.
        echo [错误] 服务启动失败，请查看系统事件查看器。
        pause
        exit /b 1
    )
) else (
    echo [4/5] 服务已在运行。
)

:: ---------- 5. 设置 root 密码 ----------
echo [5/5] 设置 root 密码为 %MYSQL_PASSWORD% ...
"%MYSQL_BIN%\mysql.exe" -h 127.0.0.1 -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '%MYSQL_PASSWORD%'; FLUSH PRIVILEGES;" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [提示] 密码设置未成功，可能之前已设置过密码。
    echo        可稍后手动执行：mysql -u root -p -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '123456';"
) else (
    echo        root 密码已设置为 123456。
)

echo.
echo ============================================================
echo  安装配置完成，验证中...
"%MYSQL_BIN%\mysql.exe" -h 127.0.0.1 -u root -p%MYSQL_PASSWORD% -e "SELECT VERSION() AS version, @@port AS port;" 2>nul
if errorlevel 1 (
    echo [警告] 验证未通过，请检查上述步骤。
) else (
    echo [OK] MySQL 服务运行正常，root 密码为 123456。
)
echo ============================================================
echo.
echo 接下来回到豆包，让我继续执行项目数据库初始化即可。
pause
