@echo off
rem ============================================================
rem 环境变量注入模板 —— 复制本文件为 env.local.bat（同目录）后填入真实值。
rem env.local.bat 已被 .gitignore 忽略（/*.bat），不会提交。
rem 这些变量对应 application.yaml 里的 ${...} 占位符。
rem 由 start-backend.bat / start-all.bat 等自动 call 加载。
rem ============================================================

rem ---- 本地 MySQL（必填：缺失后端直接启动失败）----
set "DB_USERNAME=root"
set "DB_PASSWORD=<你的本地 MySQL 口令>"

rem ---- JWT 签名密钥（必填：64 位随机串，缺失启动失败）----
rem 生成：python -c "import secrets;print(secrets.token_hex(32))"
set "JWT_SECRET=<64 位随机字符串>"

rem ---- 华为 AGC 登录凭据（可选：不填则华为一键登录不可用）----
set "HUAWEI_CLIENT_ID=<你的 AGC client-id>"
set "HUAWEI_CLIENT_SECRET=<你的 AGC client-secret>"

rem ---- DeepSeek AI（可选：不填则 AI 解读不可用）----
set "DEEPSEEK_API_KEY=<你的 DeepSeek api-key>"
