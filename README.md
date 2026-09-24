- # HarmonyOS NEXT 心理健康辅导系统（全栈架构演进版）

  ## 一、项目简介

  HarmonyOS NEXT 心理健康辅导系统是一个面向个人情绪记录、心理测评与状态展示的**前后端分离 + 全栈架构**项目。
  项目并非简单的页面展示，而是围绕“登录注册 → 个人资料 → 情绪日记 → 心理测评（离线优先） → 记录统计 → 首页状态展示 → AI陪伴聊天”构建完整的业务闭环。本项目已作为**秋招实习投递与面试讲解的核心作品**进行打磨，并持续推进架构演进。

  本项目重点体现以下能力：

  - HarmonyOS NEXT 应用开发与 ArkTS V1/V2 状态管理演进
  - 前后端分离与全栈开发能力（Spring Boot 3 + MySQL）
  - 无状态 JWT 鉴权、OAuth 2.0（华为登录）与 Redis 安全加固（规划中）
  - 弱网环境下的离线优先（Offline-First）架构设计与多级缓存降级策略
  - 复杂工程问题的排查、重构与版本控制能力
  - 现代前端工程化与部署架构（Vue 3 + Vite + Nginx）

  ## 二、项目背景

  随着学习与就业压力增加，情绪记录与心理状态自我管理的需求明显。相比单一的信息展示，本项目围绕“心理状态记录与反馈”构建真实的商业雏形。用户可完成登录、日记记录、心理测评、数据统计以及基础 AI 陪伴式交互。项目包含真实用户数据、登录鉴权、业务入库、结果展示与页面联动的完整数据流。

  ## 三、项目目标

  ### 1. 功能目标

  - 登录注册、个人资料查看与编辑
  - 头像上传与回显、情绪日记查看与记录
  - 心理测评列表、答题、提交与结果入库
  - 首页状态摘要与“我的页”统计联动
  - AI 陪伴聊天基础交互

  ### 2. 工程目标

  搭建高可维护的前后端分离架构，形成页面层、服务层、数据存储层、统一网络请求层的清晰分层。

  ### 3. 求职目标

  作为暑期实习简历投递、面试项目讲解与后续可上架产品的基础版本。

  ## 四、技术栈

  ### 客户端（鸿蒙）

  - HarmonyOS NEXT / ArkTS / ArkUI（V1 现状，V2 迁移规划中）
  - 离线缓存：Preferences / RelationalStore（待接入）
  - 网络层：@kit.NetworkKit
  - 架构模式：MVVM + Repository（多级缓存策略）

  ### 后端

  - Java / Spring Boot 3
  - Spring Security + JWT（双 Token 机制）
  - MyBatis-Plus / MySQL
  - Redis（黑名单与限流，规划中）

  ### 管理后台（规划中）

  - Vue 3 + Vite + Element Plus + Pinia + Axios
  - Nginx 同源反向代理，动静分离

  ## 五、系统架构

  ### 1. 客户端架构

  - **页面层**：HomePageNew、MePage、LoginPage、ProfileEditPage、MoodDiaryPage、AssessmentsPage、AIChatPage、记录统计页。
  - **服务层**：ApiService（统一网络请求）、AppAuthService（登录态与 Token 管理）、ScaleRepository（量表多级缓存与 SWR 降级）、HuaweiIdService（华为 OAuth）。
  - **公共层**：AppPageHeader、AvatarComponent、StateComponents、主题令牌。

  ### 2. 后端架构

  典型分层：Controller → Service → Mapper → Entity/DTO。负责用户登录注册、JWT 鉴权、日记与测评接口、头像上传及数据持久化。

  ### 3. 管理后台（独立部署）

  前端独立 Vue 工程，通过 Nginx 同源反代 `/api` 到 Spring Boot 服务，解决跨域并实现前后端彻底分离。

  ## 六、核心业务模块（升级重点）

  ### 1. 登录注册模块

  已实现账号密码登录、JWT 下发、本地持久化与静默恢复。华为 OAuth 授权码一键登录链路已闭环，后端通过 `HuaweiAuthService` 换取 UnionId 并自动绑定本地用户，签发 JWT。

  ### 2. 心理测评模块（痛点改造）

  **原痛点**：题目存在后端数据库，每次做题都需网络请求，弱网或断网直接导致核心功能不可用。
  **重构方案**：

  - **题库静态化**：后端将题库导出为 `static/scales/{id}.json`，通过 `ScalePublishService` 管理发布。
  - **离线优先（Offline-First）**：客户端 `ScaleRepository` 采用 **SWR（Stale-While-Revalidate）** 策略。
  - **多级降级**：内存 → 本地 Preferences 缓存 → 网络拉取 → `rawfile` 兜底（确保零网络也能答题）。
  - **幂等提交**：断网时写入本地 `RelationalStore` 队列，联网后由 `PendingSubmitWorker` 自动重投，通过 `clientSubmitId` 唯一索引保证不会重复计分。

  ### 3. AI 陪伴聊天模块

  页面结构、对话列表与输入区域已完成，后续可接入真实 AI 接口与大模型流式输出（利用 V2 的 `@Trace` 对象实时刷新特性）。

  ### 4. 其他模块

  个人资料、头像、日记、统计等模块均已完成前后端接口联调闭环，支持数据真实落库。

  ## 七、数据库设计

  - **user**：用户基本信息。
  - **diary**：情绪日记，按 user_id 与时间复合索引。
  - **assessment**：测评定义与类型信息。
  - **assessment_result**：测评结果，包含得分、等级与建议。
    *补充：添加了 migration 脚本，修复了历史上因 SQL 迁移脚本导致的题库覆盖问题，确保新老数据一致。*

  ## 八、登录鉴权流程（安全加固）

  1. 用户登录/华为 OAuth 授权，前端拿到 code 或账号密码。
  2. 后端校验成功，生成 JWT（Access）和 RefreshToken。
  3. 前端 `TokenManager` 统一保存，`ApiService` 拦截器自动携带 `Bearer Token`。
  4. 后端 Spring Security 过滤器解析 Token，注入 UserId。
  5. **安全升级（规划）**：JWT payload 加入 `typ`（user/admin）与 `role` 字段，实现权限分级隔离；引入 Redis 黑名单机制，解决无状态 JWT 无法主动登出的痛点。
  6. 401 统一拦截，前端清理缓存并跳转登录页。

  ## 九、项目亮点（面试必考）

  1. **弱网多级缓存与 SWR 降级**：彻底解决测评断网不可用，从架构层面保证高可用。
  2. **无状态鉴权安全加固**：双 Token + Redis 黑名单 + 角色分离（规划/实施中）。
  3. **题库动态发布闭环**：后台管理修改题库 → 触发静态 JSON 导出 → 客户端通过 manifest 版本号增量更新。
  4. **前后端分离工程化**：管理后台从 600 行内联 HTML 重构为 Vue 3 独立工程，Nginx 反代部署。
  5. **真实工程问题排查**：定位并修复 SQL 迁移脚本中的 `WHERE` 条件死角，防止业务数据错乱。

  ## 十、当前完成情况

  ### 已完成

  - S0：死代码清理，模块重构（清除 `mindHealth/` 残留，统一工程目录为 `client/`）
  - S2：题库静态化（后端 JSON 导出 + 接口放行 + SQL 数据迁移 Bug 修复）
  - 核心业务：登录注册、JWT 鉴权、日记、测评、资料编辑、统计等主链路全部闭环，本地可完整演示。

  ### 进行中（AI 代理自动化执行）

  - S3：客户端 `ScaleRepository` 接入离线题库与 rawfile 兜底
  - S4-S6：ArkTS V1 向 V2（`@ComponentV2`、`@Trace`）状态管理迁移
  - S7-S8：后端 Redis 黑名单与独立 Vue 管理后台重构

  ## 十一、项目收获（从工程视角）

  - 掌握了 HarmonyOS NEXT 端云一体与离线缓存架构
  - 理解并实践了 JWT、OAuth 2.0、Redis 等无状态鉴权体系
  - 提升了多模块 Monorepo 版本管理与 Git 分支/标签控制能力
  - 提升了全栈排查问题、重构代码与验证生产级可用性的能力

  ## 十二、后续计划

  - 完成 ArkTS V2 状态管理迁移（视 S4-S6 验收结果决定是否回滚至 V1）
  - 接入 Redis 实现 JWT 黑名单与 AI 接口限流
  - 完成 Vue 3 + Vite 管理后台独立部署，Nginx 同源反代
  - 打磨演示视频与作品集 PDF，直接用于秋招投递

  ## 十三、运行说明

  ### 客户端

  1. 使用 DevEco Studio 打开 `client/` 工程
  2. 启动模拟器或真机运行（断网测试可提前体验离线题库）

  ### 后端

  1. 启动 MySQL，配置 `application.yaml` 连接（本地开发用 `application-local.yaml`）
  2. 启动 Spring Boot 项目（`mvn spring-boot:run`），端口 9000

  ### 管理后台（S8 完成后）

  1. `cd admin && npm install && npm run dev`
  2. 开发环境 Vite 代理 `/api` 到 `localhost:9000`；生产环境由 Nginx 接管