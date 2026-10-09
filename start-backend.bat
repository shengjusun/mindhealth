@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set "JAR=backend\target\backend-1.0.0.jar"

echo ============================================
echo   轻心 - 后端（jar）
echo ============================================
echo.

if not exist "%JAR%" (
  echo [1/2] 未找到 jar，开始打包（首次可能需要几分钟）...
  echo.
  pushd backend
  call mvn clean package -DskipTests
  popd
  echo.
)

if not exist "%JAR%" (
  echo [x] 打包失败。
  echo     请确认：已安装 JDK 17 与 Maven，并且 mvn 在 PATH 中。
  echo.
  pause
  exit /b 1
)

echo [2/2] 启动后端：http://localhost:9000/api
echo       停止：按 Ctrl+C，或直接关闭本窗口。
echo.
cd backend
java -jar target\backend-1.0.0.jar
