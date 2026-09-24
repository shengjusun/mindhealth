<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { deleteFeedback, fetchFeedbacks, handleFeedback, type FeedbackRow } from '../api/admin'
import { formatTime } from '../utils/format'

const loading = ref(false)
const handledFilter = ref<string>('all')
const page = ref(1)
const size = 10
const total = ref(0)
const rows = ref<FeedbackRow[]>([])

async function load(): Promise<void> {
  loading.value = true
  try {
    const params: { page: number; size: number; handled?: boolean } = { page: page.value, size }
    if (handledFilter.value === 'handled') params.handled = true
    if (handledFilter.value === 'unhandled') params.handled = false
    const res = await fetchFeedbacks(params)
    rows.value = res.records ?? []
    total.value = res.total ?? 0
  } catch {
    /* 拦截器已提示 */
  } finally {
    loading.value = false
  }
}

function onFilterChange(): void {
  page.value = 1
  void load()
}

async function onHandle(row: FeedbackRow): Promise<void> {
  try {
    await ElMessageBox.confirm('标记该反馈为已处理？', '提示', { type: 'warning' })
    await handleFeedback(row.id)
    ElMessage.success('已标记处理')
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

async function onDelete(row: FeedbackRow): Promise<void> {
  try {
    await ElMessageBox.confirm(`确定删除反馈 #${row.id}？`, '危险操作', {
      type: 'warning',
      confirmButtonText: '删除',
    })
    await deleteFeedback(row.id)
    ElMessage.success('删除成功')
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

onMounted(load)
</script>

<template>
  <el-card shadow="never">
    <template #header>
      <div class="toolbar">
        <el-select v-model="handledFilter" style="width: 160px" @change="onFilterChange">
          <el-option label="全部反馈" value="all" />
          <el-option label="未处理" value="unhandled" />
          <el-option label="已处理" value="handled" />
        </el-select>
        <el-button size="small" @click="load">刷新</el-button>
      </div>
    </template>

    <el-table v-loading="loading" :data="rows" border stripe>
      <el-table-column prop="id" label="ID" width="70" />
      <el-table-column label="提交人" width="120">
        <template #default="{ row }">{{ row.author || '-' }}</template>
      </el-table-column>
      <el-table-column label="类型" width="110">
        <template #default="{ row }">
          <el-tag size="small" type="info">{{ row.type || '-' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="内容" min-width="260">
        <template #default="{ row }">
          <el-tooltip :content="row.content" placement="top" :show-after="300">
            <span class="clip">{{ row.content }}</span>
          </el-tooltip>
        </template>
      </el-table-column>
      <el-table-column label="联系方式" width="140">
        <template #default="{ row }">{{ row.contact || '-' }}</template>
      </el-table-column>
      <el-table-column label="提交时间" width="170">
        <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
      </el-table-column>
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.isHandled ? 'success' : 'warning'" size="small">
            {{ row.isHandled ? '已处理' : '未处理' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="140" fixed="right">
        <template #default="{ row }">
          <el-button v-if="!row.isHandled" link type="primary" @click="onHandle(row)">标记处理</el-button>
          <el-button link type="danger" @click="onDelete(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <div class="pager">
      <el-pagination
        v-model:current-page="page"
        background
        layout="total, prev, pager, next"
        :total="total"
        :page-size="size"
        @current-change="load"
      />
    </div>
  </el-card>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
}
.pager {
  display: flex;
  justify-content: flex-end;
  margin-top: 12px;
}
.clip {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
}
</style>