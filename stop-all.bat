@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ============================================
echo   轻心 - 关闭所有服务（9000 / 5173 / 5174）
echo ============================================
echo.

set "FOUND=0"

for %%P in (9000 5173 5174) do (
  for /f "tokens=5" %%A in ('netstat -ano ^| findstr ":%%P" ^| findstr LISTENING') do (
    if not defined SEEN_%%A (
      set "SEEN_%%A=1"
      echo   关闭端口 %%P -^> PID %%A
      taskkill /F /PID %%A >nul 2>&1
      set "FOUND=1"
    )
  )
)

echo.
if "%FOUND%"=="0" (
  echo 没有发现占用这些端口的进程。
) else (
  echo 已发出关闭指令。
)

echo.
echo 复查（下面没有输出 = 端口已全部释放）：
netstat -ano | findstr ":9000 :5173 :5174" | findstr LISTENING
echo.
pause
