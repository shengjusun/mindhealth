<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { fetchStats, type AdminStats } from '../api/admin'

const loading = ref(false)
const stats = ref<AdminStats | null>(null)

async function load(): Promise<void> {
  loading.value = true
  try {
    stats.value = await fetchStats()
  } catch {
    /* 拦截器已提示 */
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div v-loading="loading">
    <el-card shadow="never">
      <template #header>
        <div class="card-header">
          <span>数据概览</span>
          <el-button size="small" @click="load">刷新</el-button>
        </div>
      </template>
      <div class="stats-grid">
        <el-card shadow="never" class="stat">
          <div class="stat-label">注册用户</div>
          <div class="stat-value">{{ stats?.userCount ?? '-' }}</div>
        </el-card>
        <el-card shadow="never" class="stat">
          <div class="stat-label">日记总数</div>
          <div class="stat-value">{{ stats?.diaryCount ?? '-' }}</div>
        </el-card>
        <el-card shadow="never" class="stat">
          <div class="stat-label">测评记录</div>
          <div class="stat-value">{{ stats?.assessmentResultCount ?? '-' }}</div>
        </el-card>
        <el-card shadow="never" class="stat">
          <div class="stat-label">待处理反馈</div>
          <div class="stat-value warn">{{ stats?.feedbackUnhandled ?? '-' }}</div>
        </el-card>
        <el-card shadow="never" class="stat">
          <div class="stat-label">反馈总数</div>
          <div class="stat-value">{{ stats?.feedbackTotal ?? '-' }}</div>
        </el-card>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px;
}
.stat {
  border: 1px solid #ebeef5;
}
.stat-label {
  color: #909399;
  font-size: 13px;
  margin-bottom: 8px;
}
.stat-value {
  font-size: 26px;
  font-weight: 600;
  color: #409eff;
}
.stat-value.warn {
  color: #e6a23c;
}
</style>