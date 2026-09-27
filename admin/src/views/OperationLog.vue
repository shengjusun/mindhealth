<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { fetchOperationLogs, type OperationLog } from '../api/admin'
import { csvFilename, exportCsv } from '../utils/csv'
import { formatTime } from '../utils/format'

const loading = ref(false)
const keyword = ref('')
const page = ref(1)
const size = ref(20)
const total = ref(0)
const rows = ref<OperationLog[]>([])

async function load(): Promise<void> {
  loading.value = true
  try {
    const res = await fetchOperationLogs({
      page: page.value,
      size: size.value,
      keyword: keyword.value || undefined,
    })
    rows.value = res.records ?? []
    total.value = res.total ?? 0
  } catch {
    /* 拦截器已提示 */
  } finally {
    loading.value = false
  }
}

function onSearch(): void {
  page.value = 1
  void load()
}

function onReset(): void {
  keyword.value = ''
  page.value = 1
  void load()
}

function onSizeChange(): void {
  page.value = 1
  void load()
}

function methodTagType(method: string): 'success' | 'warning' | 'danger' | 'info' {
  if (method === 'POST') return 'success'
  if (method === 'PUT') return 'warning'
  if (method === 'DELETE') return 'danger'
  return 'info'
}

function onExport(): void {
  const header = ['时间', '操作人', '操作', '对象', '方法', '路径', 'IP', '状态', '耗时(ms)']
  const data = rows.value.map((row) => [
    formatTime(row.createTime),
    row.adminUsername || '',
    row.action || '',
    row.target || '',
    row.method || '',
    row.path || '',
    row.ip || '',
    row.status ?? '',
    row.durationMs ?? '',
  ])
  exportCsv(csvFilename('操作日志'), header, data)
  ElMessage.success(`已导出当前页 ${data.length} 条记录`)
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="panel">
      <div class="panel__head">
        <el-input
          v-model="keyword"
          class="search"
          placeholder="搜索操作、路径、管理员、IP 或对象"
          clearable
          @keyup.enter="onSearch"
        >
          <template #prefix>
            <el-icon><Search /></el-icon>
          </template>
        </el-input>
        <el-button type="primary" @click="onSearch">查询</el-button>
        <el-button @click="onReset">重置</el-button>
        <div class="spacer" />
        <el-button :loading="loading" @click="load">
          <el-icon><Refresh /></el-icon>刷新
        </el-button>
        <el-button @click="onExport">
          <el-icon><Download /></el-icon>导出 CSV
        </el-button>
      </div>

      <div class="notice">
        <el-icon><InfoFilled /></el-icon>
        <span>
          仅记录有后果的操作：全部写操作，以及读取用户日记 / 用户详情的请求。
          登录、验证码、纯统计查询不记录。
        </span>
      </div>

      <el-table v-loading="loading" :data="rows">
        <el-table-column label="操作时间" width="180">
          <template #default="{ row }">
            <span class="mono">{{ formatTime(row.createTime) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作人" width="140">
          <template #default="{ row }">
            <span class="strong">{{ row.adminUsername || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" min-width="170">
          <template #default="{ row }">
            <span class="action">{{ row.action || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="对象" width="130">
          <template #default="{ row }">
            <span class="mono">{{ row.target || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="请求" min-width="280">
          <template #default="{ row }">
            <div class="req">
              <el-tag :type="methodTagType(row.method)" size="small" effect="dark">
                {{ row.method }}
              </el-tag>
              <span class="mono path text-clip">{{ row.path }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="来源 IP" width="140">
          <template #default="{ row }">
            <span class="mono">{{ row.ip || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="耗时" width="100" align="right">
          <template #default="{ row }">
            <span v-if="row.status && row.status !== 200" class="bad-status">
              {{ row.status }}
            </span>
            <span v-else class="mono">{{ row.durationMs ?? '-' }} ms</span>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="暂无操作记录" :image-size="80" />
        </template>
      </el-table>

      <div class="panel__foot">
        <el-pagination
          v-model:current-page="page"
          v-model:page-size="size"
          background
          :page-sizes="[20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          :total="total"
          @current-change="load"
          @size-change="onSizeChange"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.search {
  width: 300px;
}

.notice {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 18px;
  font-size: 12.5px;
  color: var(--text-3);
  background: rgba(77, 124, 254, 0.06);
  border-bottom: 1px solid var(--border);
}

.notice .el-icon {
  color: var(--brand-300);
  flex: none;
}

.strong {
  font-weight: 600;
  color: var(--text-1);
}

.action {
  color: var(--text-1);
}

.req {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}

.path {
  font-size: 12px;
  color: var(--text-3);
}

.bad-status {
  font-weight: 600;
  color: #ff7a8a;
}
</style>
