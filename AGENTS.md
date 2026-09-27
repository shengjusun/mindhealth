# 项目工作约定

## 后端服务生命周期（硬性要求）

- 后端默认**不常驻**：需要启动服务做测试时才启动（`cd backend && mvn spring-boot:run`），**测试完毕必须立即关闭**，用户会自己按需启动。
- 关闭时注意：Windows 下 `mvn spring-boot:run` 被 TaskStop/杀掉后，其派生的 **java 子进程会成为孤儿进程继续占用 9000 端口**。必须显式清理：
  ```bash
  PID=$(netstat -ano | grep ":9000" | grep LISTENING | head -1 | awk '{print $NF}')
  taskkill //PID $PID //F
  ```
  并用 `netstat -ano | grep :9000` 复查确认端口完全释放，才算关闭完成。

## 本地私密配置

- `backend/src/main/resources/application-local.yaml`（已 gitignore）存放华为 AGC 凭据与 DeepSeek key，不进 git，key 不要套 `${...}` 占位符（会被 Spring 当属性名解析成空串）。
