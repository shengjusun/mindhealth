<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  batchOperate,
  deleteFeedback,
  fetchFeedbacks,
  handleFeedback,
  type FeedbackRow,
} from '../api/admin'
import { csvFilename, exportCsv } from '../utils/csv'
import { formatTime } from '../utils/format'

const router = useRouter()

const loading = ref(false)
const handledFilter = ref<string>('all')
const keyword = ref('')
const page = ref(1)
const size = ref(10)
const total = ref(0)
const rows = ref<FeedbackRow[]>([])
const selected = ref<FeedbackRow[]>([])

const detailVisible = ref(false)
const detail = ref<FeedbackRow | null>(null)

async function load(): Promise<void> {
  loading.value = true
  try {
    const params: { page: number; size: number; handled?: boolean; keyword?: string } = {
      page: page.value,
      size: size.value,
    }
    if (handledFilter.value === 'handled') params.handled = true
    if (handledFilter.value === 'unhandled') params.handled = false
    if (keyword.value) params.keyword = keyword.value
    const res = await fetchFeedbacks(params)
    rows.value = res.records ?? []
    total.value = res.total ?? 0
    selected.value = []
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

function onSearch(): void {
  page.value = 1
  void load()
}

function onReset(): void {
  keyword.value = ''
  handledFilter.value = 'all'
  page.value = 1
  void load()
}

function onSizeChange(): void {
  page.value = 1
  void load()
}

/** 跳到用户管理，并直接打开这个提交人的详情抽屉 */
function goUser(userId: number): void {
  if (!userId) return
  void router.push({ path: '/users', query: { detail: String(userId) } })
}

function openDetail(row: FeedbackRow): void {
  detail.value = row
  detailVisible.value = true
}

async function onHandle(row: FeedbackRow): Promise<void> {
  try {
    await ElMessageBox.confirm('将该反馈标记为已处理？', '提示', { type: 'warning' })
    await handleFeedback(row.id)
    ElMessage.success('已标记处理')
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

async function onDelete(row: FeedbackRow): Promise<void> {
  try {
    await ElMessageBox.confirm(`确定删除反馈 #${row.id}？此操作不可恢复。`, '危险操作', {
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

function onSelectionChange(rowsSelected: FeedbackRow[]): void {
  selected.value = rowsSelected
}

async function onBatch(action: 'handle' | 'delete'): Promise<void> {
  const ids = selected.value.map((item) => item.id)
  if (!ids.length) return
  const label = action === 'handle' ? '批量标记已处理' : '批量删除'
  try {
    await ElMessageBox.confirm(
      action === 'delete'
        ? `确定删除选中的 ${ids.length} 条反馈？此操作不可恢复。`
        : `确定将选中的 ${ids.length} 条反馈标记为已处理？`,
      action === 'delete' ? '危险操作' : '提示',
      { type: 'warning', confirmButtonText: '确定' },
    )
    const res = await batchOperate('feedback', action, ids)
    ElMessage.success(`${label}成功，影响 ${res?.affected ?? ids.length} 条`)
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

function onExport(): void {
  const header = ['ID', '用户ID', '提交人', '类型', '内容', '联系方式', '状态', '提交时间', '处理时间']
  const data = rows.value.map((row) => [
    row.id,
    row.userId,
    row.author || '',
    row.type || '',
    (row.content || '').replace(/\s+/g, ' '),
    row.contact || '',
    row.isHandled ? '已处理' : '未处理',
    formatTime(row.createTime),
    row.handledTime ? formatTime(row.handledTime) : '',
  ])
  exportCsv(csvFilename('用户反馈'), header, data)
  ElMessage.success(`已导出当前页 ${data.length} 条记录`)
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="panel">
      <div class="panel__head">
        <el-select v-model="handledFilter" class="filter" @change="onFilterChange">
          <el-option label="全部反馈" value="all" />
          <el-option label="未处理" value="unhandled" />
          <el-option label="已处理" value="handled" />
        </el-select>
        <el-input
          v-model="keyword"
          class="search"
          placeholder="搜索内容 / 联系方式 / 类型"
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
        <el-button size="small" text type="primary" @click="load">刷新</el-button>
      </div>

      <div v-if="selected.length" class="batch-bar">
        <el-icon><Select /></el-icon>
        <span>已选中 <b>{{ selected.length }}</b> 项</span>
        <div class="spacer" />
        <el-button size="small" @click="onBatch('handle')">批量标记已处理</el-button>
        <el-button size="small" type="danger" plain @click="onBatch('delete')">批量删除</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" @selection-change="onSelectionChange">
        <el-table-column type="selection" width="46" />
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="提交人" width="140">
          <template #default="{ row }">
            <el-button
              v-if="row.userId"
              link
              type="primary"
              @click="goUser(row.userId)"
            >
              {{ row.author || `#${row.userId}` }}
            </el-button>
            <span v-else class="strong">{{ row.author || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="类型" width="110">
          <template #default="{ row }">
            <el-tag size="small" type="info" effect="light">{{ row.type || '-' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="内容" min-width="260">
          <template #default="{ row }">
            <el-tooltip :content="row.content" placement="top" :show-after="300">
              <span class="text-clip">{{ row.content }}</span>
            </el-tooltip>
          </template>
        </el-table-column>
        <el-table-column label="联系方式" width="150">
          <template #default="{ row }">
            <span class="mono">{{ row.contact || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="提交时间" width="170">
          <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="95">
          <template #default="{ row }">
            <el-tag :type="row.isHandled ? 'success' : 'warning'" size="small" effect="light">
              {{ row.isHandled ? '已处理' : '未处理' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row)">详情</el-button>
            <el-button v-if="!row.isHandled" link type="primary" @click="onHandle(row)">
              标记处理
            </el-button>
            <el-button link type="danger" @click="onDelete(row)">删除</el-button>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="暂无反馈数据" :image-size="80" />
        </template>
      </el-table>

      <div class="panel__foot">
        <el-pagination
          v-model:current-page="page"
          v-model:page-size="size"
          background
          :page-sizes="[10, 20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          :total="total"
          @current-change="load"
          @size-change="onSizeChange"
        />
      </div>
    </div>

    <el-dialog v-model="detailVisible" title="反馈详情" width="600px" align-center>
      <div v-if="detail" class="detail">
        <div class="detail-meta">
          <el-button
            v-if="detail.userId"
            link
            type="primary"
            @click="goUser(detail.userId)"
          >
            {{ detail.author || `#${detail.userId}` }}
          </el-button>
          <span v-else class="strong">{{ detail.author || '未知用户' }}</span>
          <el-tag size="small" type="info" effect="light">{{ detail.type || '其他' }}</el-tag>
          <el-tag
            :type="detail.isHandled ? 'success' : 'warning'"
            size="small"
            effect="light"
          >
            {{ detail.isHandled ? '已处理' : '未处理' }}
          </el-tag>
          <span>{{ formatTime(detail.createTime) }}</span>
        </div>
        <div class="detail-content">{{ detail.content || '（无内容）' }}</div>
        <div class="detail-foot">
          <span>联系方式：{{ detail.contact || '未提供' }}</span>
          <span v-if="detail.handledTime">处理时间：{{ formatTime(detail.handledTime) }}</span>
        </div>
      </div>
      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
        <el-button
          v-if="detail && !detail.isHandled"
          type="primary"
          @click="detail && onHandle(detail)"
        >
          标记为已处理
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.filter {
  width: 160px;
}

.search {
  width: 260px;
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

.detail-meta {
  display: flex;
  align-items: center;
  gap: 10px;
  padding-bottom: 14px;
  font-size: 12px;
  color: var(--text-3);
  border-bottom: 1px solid var(--border);
}

.detail-content {
  padding: 16px 0;
  font-size: 13px;
  line-height: 1.85;
  color: var(--text-2);
  white-space: pre-wrap;
  word-break: break-word;
}

.detail-foot {
  display: flex;
  gap: 20px;
  padding-top: 14px;
  font-size: 12px;
  color: var(--text-3);
  border-top: 1px solid var(--border);
}
</style>
