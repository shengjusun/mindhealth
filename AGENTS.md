# 项目工作约定

## 后端服务生命周期（硬性要求）

- 后端默认**不常驻**：需要启动服务做测试时才启动（`cd backend && mvn spring-boot:run`），**测试完毕必须立即关闭**，用户会自己按需启动。
- 关闭时注意：Windows 下 `mvn spring-boot:run` 被 TaskStop/杀掉后，其派生的 **java 子进程会成为孤儿进程继续占用 9000 端口**。必须显式清理：
  ```bash
  PID=$(netstat -ano | grep ":9000" | grep LISTENING | head -1 | awk '{print $NF}')
  taskkill //PID $PID //F
  ```
  并用 `netstat -ano | grep :9000` 复查确认端口完全释放，才算关闭完成。

## 客户端编译与验证（本机已可用）

客户端**不依赖打开 DevEco IDE 就能编译**。在 `client/` 目录下执行：

```bash
cd D:/harmony/Project/mh/client
export DEVECO_SDK_HOME="D:/harmony/deveco6.1/DevEco Studio/sdk"
"D:/harmony/deveco6.1/DevEco Studio/tools/node/node.exe" \
"D:/harmony/deveco6.1/DevEco Studio/tools/hvigor/bin/hvigorw.js" \
assembleHap --mode module -p product=default -p module=entry@default --no-daemon
```

- 产物：`client/entry/build/default/outputs/default/entry-default-signed.hap`
- 增量编译约 3~5 秒（首次全量较慢）。成功标志：`BUILD SUCCESSFUL`。
- **改动客户端代码后，必须先编译通过再交付**，不要凭"看起来对"就交。
- ⚠️ **编译通过 ≠ 功能正确**。接续（Continuity）、分布式等能力**必须真机验证**——**模拟器不支持接续**。

## 本地私密配置

- `backend/src/main/resources/application-local.yaml`（已 gitignore）存放华为 AGC 凭据与 DeepSeek key，不进 git，key 不要套 `${...}` 占位符（会被 Spring 当属性名解析成空串）。
