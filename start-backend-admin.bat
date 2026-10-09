@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================
echo   轻心 - 后端(jar) + admin
echo ============================================
echo.

set "JAR=backend\target\backend-1.0.0.jar"

echo [1/2] 后端
if not exist "%JAR%" (
  echo       未找到 jar，先打包（首次较慢）...
  pushd backend
  call mvn clean package -DskipTests
  popd
)
if not exist "%JAR%" (
  echo       [x] 打包失败，跳过后端。请检查 JDK / Maven。
) else (
  start "轻心-后端(9000)" /D "%~dp0backend" cmd /k "chcp 65001 >nul && java -jar target\backend-1.0.0.jar"
)

echo [2/2] admin
if exist "admin\package.json" (
  if not exist "admin\node_modules" (
    echo       首次运行，安装依赖...
    pushd admin
    call npm install
    popd
  )
  start "轻心-admin(5173)" /D "%~dp0admin" cmd /k "chcp 65001 >nul && npm run dev"
) else (
  echo       admin\ 不存在，跳过
)

echo.
echo 端口：后端 9000（/api） / admin 5173
echo 关闭：双击 stop-all.bat
echo.
pause
