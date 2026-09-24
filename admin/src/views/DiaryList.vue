<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { batchOperate, deleteDiary, fetchDiaries, type DiaryRow } from '../api/admin'
import { csvFilename, exportCsv } from '../utils/csv'
import { formatTime } from '../utils/format'

const loading = ref(false)
const keyword = ref('')
const page = ref(1)
const size = 10
const total = ref(0)
const rows = ref<DiaryRow[]>([])
const selected = ref<DiaryRow[]>([])

const detailVisible = ref(false)
const detail = ref<DiaryRow | null>(null)

async function load(): Promise<void> {
  loading.value = true
  try {
    const res = await fetchDiaries({ page: page.value, size, keyword: keyword.value || undefined })
    rows.value = res.records ?? []
    total.value = res.total ?? 0
    selected.value = []
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

function openDetail(row: DiaryRow): void {
  detail.value = row
  detailVisible.value = true
}

async function onDelete(row: DiaryRow): Promise<void> {
  try {
    await ElMessageBox.confirm(`确定删除日记「${row.title || row.id}」？此操作不可恢复。`, '危险操作', {
      type: 'warning',
      confirmButtonText: '删除',
    })
    await deleteDiary(row.id)
    ElMessage.success('删除成功')
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

function onSelectionChange(rowsSelected: DiaryRow[]): void {
  selected.value = rowsSelected
}

async function onBatchDelete(): Promise<void> {
  const ids = selected.value.map((item) => item.id)
  if (!ids.length) return
  try {
    await ElMessageBox.confirm(`确定删除选中的 ${ids.length} 篇日记？此操作不可恢复。`, '危险操作', {
      type: 'warning',
      confirmButtonText: '删除',
    })
    const res = await batchOperate('diary', 'delete', ids)
    ElMessage.success(`已删除 ${res?.affected ?? ids.length} 篇日记`)
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

function onExport(): void {
  const header = ['ID', '用户ID', '作者', '标题', '内容', '情绪', '强度', '创建时间']
  const data = rows.value.map((row) => [
    row.id,
    row.userId,
    row.author || '',
    row.title || '',
    (row.content || '').replace(/\s+/g, ' '),
    row.emotion || '',
    row.intensity ?? '',
    formatTime(row.createTime),
  ])
  exportCsv(csvFilename('日记列表'), header, data)
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
          placeholder="搜索标题或内容"
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
        <el-button @click="onExport">
          <el-icon><Download /></el-icon>导出 CSV
        </el-button>
      </div>

      <div v-if="selected.length" class="batch-bar">
        <el-icon><Select /></el-icon>
        <span>已选中 <b>{{ selected.length }}</b> 项</span>
        <div class="spacer" />
        <el-button size="small" type="danger" plain @click="onBatchDelete">批量删除</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" @selection-change="onSelectionChange">
        <el-table-column type="selection" width="46" />
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="作者" width="130">
          <template #default="{ row }">
            <span class="strong">{{ row.author || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="标题" min-width="150">
          <template #default="{ row }">{{ row.title || '-' }}</template>
        </el-table-column>
        <el-table-column label="内容" min-width="240">
          <template #default="{ row }">
            <el-tooltip :content="row.content" placement="top" :show-after="300">
              <span class="text-clip">{{ row.content }}</span>
            </el-tooltip>
          </template>
        </el-table-column>
        <el-table-column label="情绪" width="100">
          <template #default="{ row }">
            <el-tag size="small" type="info" effect="light">{{ row.emotion || '-' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="强度" width="80">
          <template #default="{ row }">{{ row.intensity ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="170">
          <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="130" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row)">查看</el-button>
            <el-button link type="danger" @click="onDelete(row)">删除</el-button>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="暂无日记数据" :image-size="80" />
        </template>
      </el-table>

      <div class="panel__foot">
        <el-pagination
          v-model:current-page="page"
          background
          layout="total, prev, pager, next"
          :total="total"
          :page-size="size"
          @current-change="load"
        />
      </div>
    </div>

    <el-dialog v-model="detailVisible" title="日记详情" width="620px" align-center>
      <div v-if="detail" class="detail">
        <div class="detail-title">{{ detail.title || '（无标题）' }}</div>
        <div class="detail-meta">
          <span>{{ detail.author || '未知用户' }}</span>
          <el-tag size="small" type="info" effect="light">{{ detail.emotion || '未标注' }}</el-tag>
          <span>强度 {{ detail.intensity ?? '-' }}</span>
          <span>{{ formatTime(detail.createTime) }}</span>
        </div>
        <div class="detail-content">{{ detail.content || '（无内容）' }}</div>
      </div>
      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.search {
  width: 240px;
}

.strong {
  font-weight: 600;
  color: var(--text-1);
}

.batch-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 18px;
  font-size: 13px;
  color: var(--brand-300);
  background: linear-gradient(90deg, rgba(77, 124, 254, 0.14) 0%, rgba(77, 124, 254, 0.03) 100%);
  border-bottom: 1px solid var(--border);
}

.batch-bar b {
  color: var(--text-1);
}

.detail-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-1);
  line-height: 1.5;
}

.detail-meta {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 10px 0 16px;
  padding-bottom: 14px;
  font-size: 12px;
  color: var(--text-3);
  border-bottom: 1px solid var(--border);
}

.detail-content {
  max-height: 340px;
  overflow-y: auto;
  padding: 14px 16px;
  font-size: 13px;
  line-height: 1.85;
  color: var(--text-2);
  white-space: pre-wrap;
  word-break: break-word;
  background: var(--surface-muted);
  border-radius: var(--radius-sm);
}
</style>
