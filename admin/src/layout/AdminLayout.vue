<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { clearAuth, getAdminName, getAdminRole } from '../auth'

const route = useRoute()
const router = useRouter()

const menus = [
  { path: '/dashboard', label: '数据概览', icon: 'DataLine' },
  { path: '/users', label: '用户管理', icon: 'User' },
  { path: '/diaries', label: '日记管理', icon: 'Notebook' },
  { path: '/assessments', label: '测评题库', icon: 'Document' },
  { path: '/feedback', label: '用户反馈', icon: 'ChatDotRound' },
]

const activeMenu = computed(() => route.path)
const currentTitle = computed(() => (route.meta.title as string) || '')
const isHome = computed(() => route.path === '/dashboard')
const adminName = computed(() => getAdminName() || '管理员')
const adminRole = computed(() => {
  const role = getAdminRole()
  if (!role) return '管理员账号'
  return role.toLowerCase() === 'admin' ? '超级管理员' : role
})
const initial = computed(() => adminName.value.charAt(0).toUpperCase())

async function onLogout(): Promise<void> {
  try {
    await ElMessageBox.confirm('退出后需要重新登录，确定继续？', '退出登录', {
      type: 'warning',
      confirmButtonText: '退出',
    })
    clearAuth()
    router.replace('/login')
  } catch {
    /* 取消 */
  }
}

function onCommand(command: string): void {
  if (command === 'profile') {
    router.push('/profile')
  } else if (command === 'logout') {
    void onLogout()
  }
}
</script>

<template>
  <el-container class="layout">
    <el-aside class="aside" width="var(--aside-w)">
      <div class="aside-aura" />

      <div class="brand">
        <div class="brand-mark">M</div>
        <div class="brand-text">
          <div class="brand-name">MindHealth</div>
          <div class="brand-sub">ADMIN CONSOLE</div>
        </div>
      </div>

      <div class="menu-label">功能导航</div>
      <el-menu :default-active="activeMenu" router class="menu">
        <el-menu-item v-for="m in menus" :key="m.path" :index="m.path">
          <el-icon><component :is="m.icon" /></el-icon>
          <span>{{ m.label }}</span>
        </el-menu-item>
      </el-menu>

      <div class="aside-foot">
        <span class="dot" />
        <span>服务运行中 · v1.0</span>
      </div>
    </el-aside>

    <el-container class="body">
      <el-header class="header" height="var(--header-h)">
        <el-breadcrumb separator="/">
          <el-breadcrumb-item :to="{ path: '/dashboard' }">首页</el-breadcrumb-item>
          <el-breadcrumb-item v-if="!isHome && currentTitle">{{ currentTitle }}</el-breadcrumb-item>
        </el-breadcrumb>

        <div class="spacer" />

        <div class="header-badge">
          <span class="pulse" />
          <span>系统正常</span>
        </div>

        <el-dropdown trigger="click" @command="onCommand">
          <div class="account">
            <div class="avatar">{{ initial }}</div>
            <div class="account-meta">
              <div class="account-name">{{ adminName }}</div>
              <div class="account-role">{{ adminRole }}</div>
            </div>
            <el-icon class="caret"><ArrowDown /></el-icon>
          </div>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="profile">
                <el-icon><UserFilled /></el-icon>个人资料
              </el-dropdown-item>
              <el-dropdown-item command="logout" divided>
                <el-icon><SwitchButton /></el-icon>退出登录
              </el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </el-header>

      <el-main class="main">
        <div class="main-aura main-aura--a" />
        <div class="main-aura main-aura--b" />
        <div class="main-inner">
          <router-view />
        </div>
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.layout {
  height: 100%;
  background: var(--bg);
}

/* ===== 侧边栏 ===== */
.aside {
  position: relative;
  display: flex;
  flex-direction: column;
  background: linear-gradient(180deg, var(--aside-bg-top) 0%, var(--aside-bg) 100%);
  border-right: 1px solid var(--aside-border);
  overflow: hidden;
}

.aside-aura {
  position: absolute;
  top: -90px;
  left: -60px;
  width: 240px;
  height: 240px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(77, 124, 254, 0.28) 0%, transparent 68%);
  pointer-events: none;
}

.brand {
  position: relative;
  display: flex;
  align-items: center;
  gap: 11px;
  height: var(--header-h);
  padding: 0 18px;
  border-bottom: 1px solid var(--aside-border);
  flex: none;
}

.brand-mark {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 17px;
  font-weight: 700;
  color: #fff;
  background: linear-gradient(135deg, #4d7cfe 0%, #8b7cff 55%, #22d3c5 100%);
  box-shadow: 0 8px 20px -8px rgba(77, 124, 254, 0.95), inset 0 1px 0 rgba(255, 255, 255, 0.3);
  flex: none;
}

.brand-name {
  font-size: 15px;
  font-weight: 600;
  color: var(--aside-text-strong);
  line-height: 1.25;
  letter-spacing: 0.2px;
}

.brand-sub {
  font-size: 9px;
  color: rgba(255, 255, 255, 0.36);
  line-height: 1.4;
  letter-spacing: 1.6px;
}

.menu-label {
  position: relative;
  padding: 20px 20px 8px;
  font-size: 10px;
  letter-spacing: 1.6px;
  color: rgba(255, 255, 255, 0.28);
  flex: none;
}

.menu {
  position: relative;
  flex: 1;
  border-right: none;
  padding: 0 10px;
  overflow-y: auto;
  --el-menu-bg-color: transparent;
  --el-menu-text-color: var(--aside-text);
  --el-menu-hover-bg-color: var(--aside-hover);
  --el-menu-active-color: var(--aside-text-strong);
  --el-menu-item-height: 44px;
  --el-menu-border-color: transparent;
}

.menu :deep(.el-menu-item) {
  position: relative;
  height: 44px;
  line-height: 44px;
  margin-bottom: 4px;
  padding-left: 13px !important;
  border-radius: 11px;
  font-size: 14px;
  transition: background-color 0.16s ease, color 0.16s ease;
}

.menu :deep(.el-menu-item .el-icon) {
  font-size: 17px;
  margin-right: 11px;
  width: 17px;
}

.menu :deep(.el-menu-item:hover) {
  color: var(--aside-text-strong);
}

.menu :deep(.el-menu-item.is-active) {
  color: var(--aside-text-strong);
  font-weight: 600;
  background: linear-gradient(90deg, rgba(77, 124, 254, 0.32) 0%, rgba(77, 124, 254, 0.06) 100%);
  box-shadow: inset 0 0 0 1px rgba(122, 158, 255, 0.16);
}

.menu :deep(.el-menu-item.is-active)::before {
  content: '';
  position: absolute;
  left: 0;
  top: 50%;
  transform: translateY(-50%);
  width: 3px;
  height: 20px;
  border-radius: 0 3px 3px 0;
  background: linear-gradient(180deg, var(--brand-400), var(--brand-teal));
  box-shadow: 0 0 12px rgba(111, 151, 255, 0.9);
}

.aside-foot {
  position: relative;
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 14px 20px 16px;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.3);
  border-top: 1px solid var(--aside-border);
  flex: none;
}

.dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #2ecc8f;
  box-shadow: 0 0 0 3px rgba(46, 204, 143, 0.16);
}

/* ===== 内容区 ===== */
.body {
  min-width: 0;
}

.header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 0 22px;
  background: rgba(11, 15, 25, 0.72);
  backdrop-filter: saturate(180%) blur(18px);
  -webkit-backdrop-filter: saturate(180%) blur(18px);
  border-bottom: 1px solid var(--border);
  flex: none;
}

.header :deep(.el-breadcrumb__inner) {
  font-size: 13px;
  color: var(--text-3);
  font-weight: 500;
}

.header :deep(.el-breadcrumb__inner.is-link:hover) {
  color: var(--brand-400);
}

.header :deep(.el-breadcrumb__item:last-child .el-breadcrumb__inner) {
  color: var(--text-1);
  font-weight: 600;
}

.header :deep(.el-breadcrumb__separator) {
  color: var(--text-3);
}

.header-badge {
  display: flex;
  align-items: center;
  gap: 7px;
  height: 28px;
  padding: 0 12px;
  border-radius: 999px;
  font-size: 12px;
  color: var(--text-2);
  background: rgba(46, 204, 143, 0.08);
  border: 1px solid rgba(46, 204, 143, 0.22);
}

.pulse {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #2ecc8f;
  box-shadow: 0 0 8px rgba(46, 204, 143, 0.9);
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.35;
  }
}

.account {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 5px 10px 5px 6px;
  border-radius: 999px;
  cursor: pointer;
  outline: none;
  border: 1px solid transparent;
  transition: background-color 0.16s ease, border-color 0.16s ease;
}

.account:hover {
  background: rgba(255, 255, 255, 0.05);
  border-color: var(--border);
}

.avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 600;
  color: #fff;
  background: linear-gradient(135deg, #4d7cfe 0%, #8b7cff 100%);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.28);
  flex: none;
}

.account-meta {
  line-height: 1.25;
  text-align: left;
}

.account-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
}

.account-role {
  font-size: 11px;
  color: var(--text-3);
}

.caret {
  font-size: 12px;
  color: var(--text-3);
}

.main {
  position: relative;
  padding: 22px 24px 32px;
  background: var(--bg);
  overflow-y: auto;
}

.main-inner {
  position: relative;
  z-index: 1;
}

.main-aura {
  position: fixed;
  border-radius: 50%;
  pointer-events: none;
  z-index: 0;
}

.main-aura--a {
  top: -140px;
  right: 6%;
  width: 460px;
  height: 460px;
  background: radial-gradient(circle, rgba(77, 124, 254, 0.14) 0%, transparent 70%);
}

.main-aura--b {
  bottom: -180px;
  left: 22%;
  width: 420px;
  height: 420px;
  background: radial-gradient(circle, rgba(34, 211, 197, 0.09) 0%, transparent 70%);
}
</style>
