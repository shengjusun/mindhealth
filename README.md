# 轻心 · HarmonyOS NEXT 心理健康辅导系统

## 一、项目简介

这是一个前后端分离的心理健康辅导系统：客户端为 HarmonyOS NEXT 应用，后端为 Spring Boot 服务，另有一个独立的 Vue 3 管理后台。业务闭环覆盖「登录注册 → 个人资料 → 情绪日记 → 心理测评（离线优先） → 记录统计 → 首页状态展示 → AI 陪伴聊天」，其中测评链路采用「客户端只上报逐题作答、服务端算分、AI 解读异步产出」的设计，题库在客户端做了内存/Preferences/rawfile/网络四级降级，断网也能答题。

技术栈分三端：

- **客户端（HarmonyOS NEXT）**：ArkTS / ArkUI，46 个 `.ets` 文件中的 36 个组件已全部迁移到 ArkTS V2 状态管理（`@ComponentV2` / `@Local` / `@Param` / `@Monitor` / `@ObservedV2` / `@Trace`，见 `client/entry/src/main/ets/`）；路由使用 `Navigation` + `NavPathStack` 声明式路由（`client/entry/src/main/resources/base/profile/route_map.json`）；网络层 `@kit.NetworkKit`；持久化 `@kit.ArkData` 的 Preferences；架构为 MVVM + Repository。
- **后端**：Java 17 / Spring Boot 3.1.5 / Spring Security + JWT（jjwt）/ MyBatis-Plus / MySQL 8；AI 能力为后端直连 DeepSeek Chat Completions（`backend/.../service/DeepSeekClient.java`）。
- **管理后台**：Vue 3 + Vite + TypeScript + Element Plus + ECharts + vue-router + axios（`admin/package.json`），构建产物由 Nginx 同源反代 `/api`（`admin/nginx/admin.conf`）。

## 二、系统架构

### 1. 请求链路（文字链路图）

```
[HarmonyOS 客户端]
  Page(@ComponentV2) → ApiService(统一请求/401 处理) → @kit.NetworkKit(http)
        │                                          │
        ├─ AppAuthService(登录态/Token,Preferences) │
        ├─ ScaleRepository(题库四级降级)            │
        └─ SnapshotRepository(日记/记录 SWR 快照)   │
                                                    ▼
[后端 Spring Boot, context-path: /api]
  JwtAuthenticationFilter → SecurityConfig(按角色授权)
        → Controller → Service(Impl) → Mapper(MyBatis-Plus) → MySQL
                          │
                          └─ DeepSeekClient → DeepSeek API

[管理后台 Vue]
  视图 → api/http.ts(axios) → /api/** ──(Vite 代理 / Nginx 反代)──▶ 后端

[量表题库]
  后端 ScaleService 读取 assessment 表 → /assessment/manifest、/assessment/{id}/questions
  客户端 rawfile/scales/*.json（安装包内置，断网兜底）
```

### 2. 目录结构

```
mh/
├── client/                                              # HarmonyOS NEXT 客户端
│   └── entry/src/main/
│       ├── ets/
│       │   ├── pages/                                   # 业务页面 + Index 入口 + RouteBuilders 路由出口
│       │   ├── core/
│       │   │   ├── api/ApiService.ets                   # 统一网络层
│       │   │   ├── auth/AppAuthService.ets              # 登录态/Token
│       │   │   ├── auth/HuaweiIdService.ets             # 华为账号授权
│       │   │   ├── repository/ScaleRepository.ets       # 题库多级缓存
│       │   │   └── repository/SnapshotRepository.ets    # 动态数据快照
│       │   └── common/                                  # components / constants / state / types / utils
│       └── resources/rawfile/scales/                    # 内置题库 1~6.json + manifest.json
├── backend/src/main/java/com/mindhealth/backend/        # Spring Boot 后端
│   ├── controller/  service/  service/impl/  mapper/  entity/  dto/  config/  utils/
└── admin/                                               # Vue 3 管理后台
    ├── src/views/  src/api/  src/components/EChart.vue
    └── nginx/admin.conf                                 # 同源反代配置
```

## 三、核心模块

### 1. 登录鉴权

**账号密码登录**：客户端 `LoginPage` → `AppAuthService.requestLogin`（`client/.../core/auth/AppAuthService.ets`）→ `POST /api/user/login`。后端签发 access token（24h）与 refresh token（7d），配置见 `backend/src/main/resources/application.yaml:58-61`，签发逻辑见 `backend/.../utils/JwtUtils.java:38-47`。

**华为账号一键登录**：客户端 `HuaweiIdService` 取授权码 → `POST /api/user/huawei/login`；后端 `HuaweiAuthService` 用授权码换 access_token、解析 id_token 取 `union_id`，绑定本地用户后签发 JWT（`backend/.../utils/HuaweiAuthService.java`）。

**统一鉴权**：`JwtAuthenticationFilter` 按 token subject 区分两类身份——管理员 token 的 subject 为 `admin:{id}`（`JwtUtils.SUBJECT_ADMIN_PREFIX`），其余按用户 id 处理；每次请求回查用户是否被禁用/删除，不可用则保持 `SecurityContext` 为空（fail-closed），见 `backend/.../config/JwtAuthenticationFilter.java:49-96`。

**角色授权**：`SecurityConfig` 按声明顺序授权——`/admin/accounts/**` 与 `/admin/logs/**` 需 `ROLE_SUPER_ADMIN`，其余 `/admin/**` 需 `ROLE_ADMIN`，业务接口 `authenticated()`，见 `backend/.../config/SecurityConfig.java:45-84`。

**管理端登录**另有图形验证码（`backend/.../controller/AdminAuthController.java:84-98`）。

**客户端侧**：`AppAuthService` 将用户信息与 token 存入 Preferences；`ApiService` 自动携带 `Bearer` 头，并对业务码 401 及 HTTP 401/403 统一触发登出跳登录页（`client/.../core/api/ApiService.ets:133-166`、`EntryAbility.ets:156-169`）。

### 2. 心理测评（离线优先 + 服务端算分 + 异步 AI）

**离线优先（题库四级降级）**：`ScaleRepository` 的读取优先级为 内存 → Preferences 缓存 → rawfile 内置题库 → 网络，任何一级失败都继续降级而不抛错（`client/.../core/repository/ScaleRepository.ets:4-11`，`getScaleLocal` 见 `:352-385`）。应用启动时用安装包内置题库给缓存打底（`seedFromRawFile` `:73-108`），内置文件为 `client/entry/src/main/resources/rawfile/scales/1~6.json`。

**SWR 与退避**：静默刷新失败后进入 60 秒退避窗口，避免弱网下反复发起注定失败的请求（`ScaleRepository.ets:44-47`、`isRefreshBackedOff` `:170-181`）。远端清单为空时不覆盖本地题库（`:248-255`）。

**提交只报逐题作答**：客户端提交体包含逐题 `answers` 与一个 `score` 字段（`client/.../pages/assessment/AssessmentQuestionPage.ets:313-382`），注释明确「保留总分仅为兼容，服务端以 answers 为准」（同文件 `:46-48`）。

**服务端算分**：后端按题库存的题目与选项分值重新计分，并把逐题明细序列化写入 `answers_json`；同时按量表自身的 `scoring.bands` 分级，量表未配置时按得分比例兜底（`backend/.../service/impl/AssessmentServiceImpl.java:146-204`、`resolveBand` `:238-270`）。

**0-100 状态分（越高越健康）**：原始分按量表极性归一化——症状量表（情绪/压力/焦虑/抑郁/睡眠）反转取 `100 - 占比`（积极选项得高分），正向量表（心理韧性）直接取占比；`max_score` 统一为 100，bands 阈值按 0-100 配置（25/50/75/100），逐题原始分保留在 `answers_json` 可回溯（`normalizeToWellness`，迁移见 `migration_score_normalized.sql`）。

**异步 AI 解读 + 轮询**：提交落库时 `ai_status` 置为 `pending`，随后触发异步分析，失败只写状态、不影响测评结果（`AssessmentServiceImpl.java:116-124`）。客户端在结果页按 `aiStatus` 轮询 `GET /api/assessment/result/{id}`，`pending` 时继续、`success/failed` 时分别展示或提供重试（`AssessmentQuestionPage.ets:338-395`、`:736-757`）；手动重试接口为 `POST /api/assessment/result/{id}/analyze`（`backend/.../controller/AssessmentController.java:84-93`）。

### 3. AI 陪伴聊天

客户端 `AIChatPage` 通过 `ApiService.sendMessage` 调用 `POST /api/ai/chat`（`client/.../pages/ai/AIChatPage.ets:323`、`client/.../core/api/ApiService.ets:441`）。后端为**真实调用大模型**，非模拟：

- `AIController` 收请求并返回统一响应体（`backend/.../controller/AIController.java:17-33`）。
- `AIServiceImpl` 组装 system prompt + 最近 10 轮历史 + 本次输入，调用 DeepSeek 并在成功后落库（`backend/.../service/impl/AIServiceImpl.java:78-98`、`buildMessages` `:147-173`）。
- HTTP 调用与错误分类集中在 `DeepSeekClient`：401 配置错误 / 402 额度不足 / 429 与 5xx 退避重试一次 / 超时与 IO 异常分别归类，均抛出对用户可读的中文提示（`backend/.../service/DeepSeekClient.java:54-105`）；`stream=false`（同文件 `:116`）。
- 限流为**单机内存态滑动窗口**，每用户每分钟最多 10 次，并有定时清理避免 map 膨胀（`AIServiceImpl.java:44-56`、`checkRateLimit` `:113-131`）。该限流不依赖 Redis。

历史读取 `GET /api/ai/history` 与清空 `DELETE /api/ai/history` 均已包装为统一响应体（`AIController.java:22-33`）。客户端聊天记录仅存内存，无本地持久化。

### 4. 情绪日记

后端 `DiaryController` / `DiaryServiceImpl` 提供增删改查，三处单条操作均校验 `diary.userId == userId`，列表按 token 中的 userId 过滤（`backend/.../service/impl/DiaryServiceImpl.java:37-75`）。

客户端页面：`MoodDiaryPage`（列表）、`DiaryEditPage`（新增/编辑）、`DiaryDetailPage`（详情）。列表与首页/我的页通过 `SnapshotRepository` 写入 Preferences 快照，在弱网/断网时降级展示（`client/.../core/repository/SnapshotRepository.ets`）。快照有 7000 字节上限，超出时从尾部逐条截断（见第六节）。

### 5. 设计系统（主题 / 令牌 / 温度翻译层）

- **令牌**：`client/.../common/constants/Theme.ets` 定义尺寸令牌 `Dimension`、字号令牌 `FontLevel`、主按钮配方 `ButtonStyle`，以及主题表 `THEMES`（`misty` 晨雾蓝、`forest` 森林绿、`sunset` 暖阳橙 三套，每套含深/浅两版品牌色，见 `:252-328`）。品牌色通过运行时函数 `brand()` 解析（`:336`），中性色走资源系统随深浅色自动切换。
- **主题状态**：`AppState` 用 `@ObservedV2` + `@Trace` 暴露 `themeId` / `isDark`（`client/.../common/state/AppState.ets:14-49`），主题选择经 `AppSettings` 存入 Preferences，并在 `loadContent` 之前恢复以防首帧闪色（`EntryAbility.ets:139-141`）。
- **公共组件**：`AppButton`、`AppChip`、`AppPageHeader`、`SubPageHeader`、`Skeleton`、`StateComponents`（加载/空/错误三态）、`AvatarComponent`，均位于 `client/.../common/components/`。
- **温度翻译层**：`client/.../common/utils/AssessmentTone.ets` 把后端的等级词、情绪强度等量化值翻译为不带体检感的用户话术（`softLevel` / `softIntensity` / `softLevelKind` / `emotionChipKind`），首页、结果页、记录卡共用。

### 6. 管理后台

`admin/` 是一个**独立的完整 Vue 3 工程**（非内联 HTML），依赖见 `admin/package.json`：`vue` + `vue-router` + `element-plus` + `echarts` + `axios`（未使用 Pinia）。页面（`admin/src/views/`）共 11 个：登录、仪表盘、用户列表、量表管理、测评结果、反馈管理、操作日志、个人资料、管理员账号管理、日记-用户列表、日记-用户详情。

- **登录**：走 `POST /api/admin/login`，含图形验证码；登录后按角色渲染菜单。
- **超管分级**：前端 `admin/src/auth.ts:77` 判断 `SUPER_ADMIN`，仅超管可见账号管理与操作日志；后端由 `SecurityConfig.java:48-56` 强制校验 `ROLE_SUPER_ADMIN`，并在 `AdminManageController` 中对角色变更、超管保底做了约束（`AdminManageController.java:150-244`）。
- **审计日志**：`AdminAuditInterceptor` 拦截管理端写操作并落库（`backend/.../config/AdminAuditInterceptor.java`），实体 `AdminOperationLog`，仅超管可读（`AdminLogController`、`admin/src/views/OperationLog.vue`）。
- **图表**：`ECharts` 按需引入（`admin/src/utils/echarts.ts`），仪表盘用折线/饼图展示趋势与分布（`admin/src/views/Dashboard.vue`）。

## 四、已完成 / 规划中

### 已完成（均可在代码中定位）

- **ArkTS V2 全量迁移**：46 个 `.ets` 文件中的 36 个组件全部为 `@ComponentV2`，`.ets` 源码中已无 V1 装饰器（`@State`/`@Prop`/`@Watch` 等仅残留在注释里）；`@Entry` 仅 `Index.ets` 一处。
- **路由迁移**：全项目已无 `@ohos.router` 的 import 与调用，`route_map.json` 注册 14 条路由，全部经 `Navigation`/`NavPathStack` + `RouteBuilders` 承载。
- **登录鉴权**：账号密码 + 华为授权码登录闭环，JWT 双 Token 下发与本地持久化，管理员/用户身份在过滤器内分流并按角色授权，管理端图形验证码。
- **心理测评**：题库接口（`assessment` 表为唯一来源）、客户端四级降级、服务端算分、逐题明细入库、`scoring.bands` 分级、AI 解读异步产出与轮询/重试。
- **AI 聊天**：后端真实调用 DeepSeek，含上下文拼接、错误分类与一次重试、单机内存限流；历史读取与清空契约已对齐。
- **情绪日记 / 个人资料 / 头像 / 文章 / 反馈**：前后端接口闭环，数据真实落库；头像上传含大小、类型、魔数校验与 UUID 文件名（魔数校验见 `backend/.../utils/FileUploadUtil.java:18-40`）。
- **管理后台**：独立 Vue 3 工程，覆盖用户/量表/测评/反馈/日记/操作日志/账号管理，含 ECharts 仪表盘、审计日志、超管分级。
- **设计系统**：三套主题 × 深浅双板、令牌体系、公共组件与三态组件、温度翻译层。
- **品牌与合规细节**：自定义启动图、桌面分层图标（前景/背景）与默认头像；注册页隐私政策勾选；昵称/日记标题长度上限与年龄范围校验；「消息提醒」接系统通知授权；性别第三项为「隐藏」（保密式设计，历史值已迁移）。
- **图标与品牌资源在哪**：
  - **App 分层图标**（前景 / 背景）：`client/AppScope/resources/base/media/`（`background.png`、`foreground.png`、`layered_image.json`），由 `client/AppScope/app.json5` 的 `"icon": "$media:layered_image"` 引用。
  - **启动图 / 默认头像**：`client/entry/src/main/resources/base/media/`（`startIcon.png`、`ic_avatar_default.png`）。
  - 以上是**构建与运行唯二依赖的图标资源，均已随仓库提供**；设计源稿（SVG）与栅格化脚本属本地资产，不随仓库分发 —— 需要改图标时在本地改源稿、重新导出并覆盖上面的 PNG 即可。
- **过程文档目录 `docs/`**：审计报告、走查、重构方案、实施规划等个人过程文档，**仅本地保留、不随仓库分发**（已在 `.gitignore` 中整体忽略）。

### 规划中（尚未实现）

- **Redis 落地**：`pom.xml` 与 `application.yaml:18-29` 已有 Redis 依赖与连接配置，但 Java 代码零使用，JWT 黑名单、分布式限流、缓存均未实现（当前限流为单机内存态）。
- **Token 主动失效与刷新**：无登出黑名单端点，refresh token 已签发但无刷新端点。
- **离线写队列**：断网时的日记/测评/反馈提交无本地队列与重投，当前只有离线读。
- **网络状态监听与恢复自动刷新**：未接入 `connection.createNetConnection`。
- **列表分页与 `LazyForEach`**：`/diary`、`/article/list`、`/ai/history` 均为全量返回，客户端用 `ForEach` 全量渲染。
- **全量事务化**：项目当前无 `@Transactional`，管理端级联删除（删日记/反馈/测评/AI 记录后删用户）非原子。

## 五、本地运行

### 1. 客户端（HarmonyOS）

1. 用 DevEco Studio 打开 `client/` 工程，等待依赖同步。
2. 启动模拟器或真机运行。
3. 后端地址默认写在 `client/entry/src/main/ets/common/constants/apiConfig.ets` 的 `DEFAULT_API_BASE_URL`，演示/换网络环境时改这一行；也可通过 Preferences 的 `api_base_url` 在启动时覆盖，无需重新打包（`EntryAbility.ets:133`、`apiConfig.ets:102-105`）。
4. 断开网络时，题库走内置 rawfile 仍可答题；已缓存过的日记/记录可看快照。

### 2. 必填配置（环境变量注入）

**仓库不存放任何密钥**：`application.yaml` 里的敏感项全部是 `${...}` 占位符，真实值一律通过**环境变量**注入，不写进任何会入库的文件。

首次运行前，把下表变量设到本机环境：

| 变量 | 必填 | 说明 |
|---|---|---|
| `DB_PASSWORD` | ✅ | 本地 MySQL 口令。缺失则后端直接启动失败（实测报错 `Could not resolve placeholder`） |
| `JWT_SECRET` | ✅ | JWT 签名密钥，64 位随机串。同上，缺失启动失败 |
| `HUAWEI_CLIENT_ID` / `HUAWEI_CLIENT_SECRET` | — | 华为 AGC 登录凭据。不填则华为一键登录不可用 |
| `DEEPSEEK_API_KEY` | — | DeepSeek AI 密钥。不填则 AI 解读不可用 |

注入方式（任选其一）：

- **命令行**：复制 `env.local.example.bat` 为 `env.local.bat`（已被 `.gitignore` 忽略），填入真实值；`start-backend.bat` / `start-all.bat` / `start-backend-web.bat` / `start-backend-admin.bat` 会自动 `call` 它。
- **IDE**：在 Run Configuration 的环境变量里配置同样这些变量。

生成 64 位随机串：`python -c "import secrets;print(secrets.token_hex(32))"`

> 早期版本用 `backend/src/main/resources/application-local.yaml` 存放这些值。该文件虽同样被 git 忽略，但密钥写在配置文件里易随打包/同步外泄；现统一改为环境变量注入 —— 仓库内零明文，本地明文只集中在 `env.local.bat`（已忽略）。

### 3. 后端（Spring Boot）

1. 准备 MySQL 8，创建 `mindhealth` 库。执行 `init.sql` 前，先把其中管理端种子口令的占位符 `<LOCAL_BCRYPT_HASH>`（`init.sql:125-131`）替换为**本地生成**的 BCrypt 哈希（仓库不存放任何口令哈希），生成方式：`python -c "import bcrypt;print(bcrypt.hashpw(b'你的密码', bcrypt.gensalt(10)).decode())"`，再执行 `backend/src/main/resources/init.sql`（另有若干 `migration_*.sql` 增量脚本）。
2. 数据库账号、密码、华为与 DeepSeek 的密钥等敏感配置一律走环境变量注入（见「必填配置」），不要写进 `application.yaml`；本地明文集中在 `env.local.bat`（已 gitignore）。
3. 启动：`cd backend && mvn spring-boot:run`，服务端口 `9000`，`context-path` 为 `/api`（`application.yaml:44-47`）。
4. 测试完毕请立即关闭服务，避免进程常驻。

### 4. 管理后台（Vue）

1. `cd admin && npm install`。
2. 开发：`npm run dev`，默认端口 5173，Vite 代理 `/api` 到 `http://localhost:9000`（`admin/vite.config.ts:8-16`）。
3. 构建：`npm run build`，产物输出到 `admin/dist`。
4. 生产部署参考 `admin/nginx/admin.conf`：静态资源 + `/api` 同源反代，注意后端 `context-path` 已是 `/api`，`proxy_pass` 末尾不可带斜杠。

## 六、已知限制

以下为当前代码中确实存在、尚未修复的问题，按模块列出，均可对照代码验证。

### 后端

1. **管理端种子账号口令需本地生成**：`init.sql:125-131` 的管理员口令为占位符 `<LOCAL_BCRYPT_HASH>`，建库前须本地生成 BCrypt 哈希并替换（勿把口令哈希提交到仓库）；未替换则种子口令不可用，无法登录管理端。
2. **MyBatis 全量 SQL 打印到 stdout**：`application.yaml:42` 为 `StdOutImpl`，会把含手机号、日记原文、聊天内容的 SQL 刷到日志，生产环境应改为 slf4j 或仅在 local profile 开启。
3. **改手机号接口缺失/静默丢弃**：客户端资料页构造的更新体包含 `phone`（`ProfileEditPage.ets:815-831`），但后端 `UpdateUserRequest` 白名单只有 `nickname/age/gender/avatar/signature`（`UpdateUserRequest.java:9-15`），`phone` 会被静默丢弃；真正能改手机号的 `PUT /user/phone` 客户端未接入。
4. **换绑手机号未校验验证码**：`UserServiceImpl.java:184` 为 `// TODO: 验证验证码`，`code` 参数被忽略，任意值都能换绑。
5. **华为 id_token 未验签**：`HuaweiAuthService.java:98-100` 仅 Base64 解析 payload，未做公钥验签。
6. **access 与 refresh 令牌等价**：JWT 的 access 与 refresh 仅在有效期上不同（24h / 7d），payload 中无 token 类型字段，也无 `jti`（`JwtUtils.build()` `:38-47` 只 set subject/issuedAt/expiration，access 与 refresh 共用同一分支）。因此 refresh token 可直接当 access token 调用业务接口，窗口为 7 天。正确做法是加 `typ` claim 与 `jti`，配合 Redis 黑名单与 `/user/refresh` 端点实现主动登出与刷新。当前未实现。
7. **级联删除无事务**：全项目 0 个 `@Transactional`，管理端删除用户时先清四张从表再删用户，中途失败会留下半删除状态。
8. **列表接口无分页**：`AIChatMapper.selectByUserId` 无 `LIMIT`（`AIChatMapper.java:19-20`），`/diary`、`/article/list`、`/ai/history` 均全量返回。
9. **响应包体双轨**：`Result`（带 timestamp）与 `ApiResponse`（无 timestamp）并存；业务错误码存在 `5001` 与 `400` 两种（`ApiResponse` vs `GlobalExceptionHandler`）。
10. **注册并发竞态**：注册为 check-then-insert，并发同手机号时第二笔会撞唯一键并被兜底为 500。
11. **部分配置未接线**：`file.upload.max-size` / `allowed-types` 已定义但代码内硬编码（`AvatarController`）；换头像后旧文件不删除，磁盘会单调增长。
12. **CORS 全开**：`SecurityConfig.java:91-102` 允许任意来源（`allowCredentials=false` 缓解风险）。
13. **无用的库表**：`init.sql:86-111` 的 `community_post` / `community_comment` 建表但零代码使用。
14. **列表接口下发完整正文**：`/diary` 与 `/article/list` 返回完整 `content` 字段，但客户端卡片只显示 2~3 行（`MoodDiaryPage` 的 `maxLines(3)`、`MyRecordsPage` 的 `maxLines(2)`）。低成本改进是列表接口做字段投影（`LEFT(content, 80) AS excerpt`），收益在数据量上来后显现。
15. **AI 聊天限流可被并发绕过**：`AIServiceImpl.java:79` 的 `checkRateLimit` 与 `:96` 的 `recordRate` 是分离的，中间夹着 3~10 秒的 DeepSeek 调用，同一用户并发发起的请求会全部通过检查、再各自记账，10 次/分钟的限制形同虚设。单机演示下不可见，但该限制本意是兜住 API 成本，正确做法是把检查与记账放进同一临界区（或改成令牌桶）。

### 客户端

1. **无离线写队列**：断网时发日记、提交测评、发反馈失败后内容即丢失，无本地队列与重投（全项目无 RelationalStore 及队列表）。
2. **无网络状态监听与恢复刷新**：未使用 `connection.createNetConnection`/`netStatusChange`，网络恢复后需手动下拉。
3. **快照 7000 字节上限**：`SnapshotRepository` 快照超限时从尾部截断，离线展示与在线可能存在差异且无提示。
4. **超时配置不统一**：全局 60s、登录旁路 10s、华为登录 10s/15s 三套并存。
5. **启动串行初始化**：`EntryAbility.initAndLoadPage` 依次 await 多个初始化（`EntryAbility.ets:133-149`），冷启动首帧被拖慢。
6. **长列表未分页（规模风险，非现存缺陷）**：`/diary`、`/article/list`、`/ai/history` 均为全量返回，客户端 5 处列表用 `ForEach` 全量渲染（全项目 `LazyForEach` 0 处）。当前数据量下无实际影响：单用户日记峰值 6 篇、AI 聊天 2 条、文章 4 篇。触发阈值约在单用户日记 200 篇 / AI 聊天 300 轮 / 单列表 50 项以上，届时需改为服务端分页 + `LazyForEach`。
7. **默认后端地址写死**：`apiConfig.ets` 的 `DEFAULT_API_BASE_URL` 为固定地址，换网络环境需修改或用 Preferences 覆盖。
8. ~~**死代码残留**~~：已清零——`AiChatService`、`CommonUtil`、`Enums`、`NetworkErrorComponent` 等死文件已删；`Types.ets` 裁至仅剩 AvatarService 使用的 3 个符号（289→33 行），`AppConstants.ets` 裁至 ScaleConfig/SnapshotConfig 两类（181→66 行）。
9. **「日记提醒」开关无实际作用**：「消息提醒」已接系统通知授权（打开开关时申请权限、拒绝引导系统设置、进设置页与系统状态对齐），但「日记提醒」仍仅写 Preferences——真实现需要 reminderAgent 定时提醒支持，未做。
10. **部分交互待完善**：~~测评记录卡片无详情入口~~（已修：新增 `AssessmentResultPage` 结果回放路由，测评卡可点进详情，AI 解读支持失败重试）；反馈类型固定为 `suggestion`，UI 无类型选择。
11. **「我的」页拉全量日记仅为计数**：`MePage` 调 `getDiaryList()` 后只用 `parseCount` 取条数（`MePage.ets:420`），而同一份数据 `MoodDiaryPage`、`MyRecordsPage` 已各拉一次。改进方向是新增轻量计数接口，当前数据量下未做。
12. **最近状态卡可能被空响应清空**：`HomePageNew.ets:181` 在服务端返回空数组时把 `latestAssessment` 置为 `null`，并调用 `saveAssessmentResults([])`（`:184`）覆盖本地快照，卡片会从「有数据」跳成「无数据」且无提示。仅在服务端异常返回空数组时触发，正常路径不出现。
13. **AI 解读状态为 none 时无出口**：`AssessmentQuestionPage.ets:361` 在 `result.aiStatus` 为空时置为 `'none'`；`:368` 只在 `'pending'` 时启动轮询，而 `:771-777` 的兜底分支会渲染「正在生成…」且不提供重试入口。后端提交时恒置 `pending`，正常路径不触发；若后端返回空 `aiStatus` 则永久停在假加载态。

### 管理后台

1. **依赖本机后端地址**：开发态代理固定指向 `localhost:9000`；生产部署须按实际环境调整 `admin/nginx/admin.conf`。
2. **无独立鉴权续期**：沿用后端 JWT 有效期，无刷新与主动登出黑名单（与后端限制同源）。
