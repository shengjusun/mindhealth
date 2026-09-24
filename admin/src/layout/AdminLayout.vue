<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { clearAuth, getAdminName } from '../auth'

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
const pageTitle = computed(() => (route.meta.title as string) || '')
const adminName = computed(() => getAdminName())

async function onLogout(): Promise<void> {
  try {
    await ElMessageBox.confirm('确定退出登录？', '提示', { type: 'warning' })
    clearAuth()
    router.replace('/login')
  } catch {
    /* 取消 */
  }
}
</script>

<template>
  <el-container class="layout">
    <el-aside width="210px" class="aside">
      <div class="brand">MindHealth 管理后台</div>
      <el-menu :default-active="activeMenu" router class="menu">
        <el-menu-item v-for="m in menus" :key="m.path" :index="m.path">
          <el-icon><component :is="m.icon" /></el-icon>
          <span>{{ m.label }}</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="header">
        <div class="title">{{ pageTitle }}</div>
        <div class="spacer" />
        <span class="muted">当前：{{ adminName || '管理员' }}</span>
        <el-button link type="primary" @click="onLogout">退出登录</el-button>
      </el-header>
      <el-main class="main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.layout {
  height: 100%;
}
.aside {
  background: #fff;
  border-right: 1px solid #e4e7ed;
  display: flex;
  flex-direction: column;
}
.brand {
  height: 60px;
  line-height: 60px;
  padding-left: 20px;
  font-weight: 600;
  font-size: 15px;
  border-bottom: 1px solid #e4e7ed;
}
.menu {
  border-right: none;
  flex: 1;
}
.header {
  background: #fff;
  border-bottom: 1px solid #e4e7ed;
  display: flex;
  align-items: center;
  gap: 12px;
}
.title {
  font-size: 16px;
  font-weight: 600;
}
.spacer {
  flex: 1;
}
.muted {
  color: #909399;
  font-size: 13px;
}
.main {
  padding: 16px;
  background: #f5f6f8;
}
</style>