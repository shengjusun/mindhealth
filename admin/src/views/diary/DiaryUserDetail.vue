<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  batchOperate,
  deleteDiary,
  fetchDiaries,
  fetchUserDetail,
  type DiaryRow,
  type UserDetail,
} from '../../api/admin'
import { csvFilename, exportCsv } from '../../utils/csv'
import { formatTime } from '../../utils/format'

const route = useRoute()
const router = useRouter()

const userId = Number(route.params.userId)

/* ===== 用户信息 ===== */
const userLoading = ref(false)
const userDetail = ref<UserDetail | null>(null)

const userName = computed(
  () => userDetail.value?.user.nickname || userDetail.value?.user.phone || `用户 #${userId}`,
)
const userInitial = computed(() => userName.value.charAt(0).toUpperCase())
const userDiaryCount = computed(() => userDetail.value?.diaryCount ?? 0)

/* ===== 日记列表 ===== */
const loading = ref(false)
const keyword = ref('')
const page = ref(1)
const size = ref(10)
const total = ref(0)
const rows = ref<DiaryRow[]>([])
const selected = ref<DiaryRow[]>([])

const detailVisible = ref(false)
const detail = ref<DiaryRow | null>(null)

async function loadUser(): Promise<void> {
  userLoading.value = true
  try {
    userDetail.value = await fetchUserDetail(userId)
  } catch {
    /* 拦截器已提示 */
  } finally {
    userLoading.value = false
  }
}

async function loadDiaries(): Promise<void> {
  loading.value = true
  try {
    const res = await fetchDiaries({
      page: page.value,
      size: size.value,
      keyword: keyword.value || undefined,
      userId,
    })
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
  void loadDiaries()
}

function onReset(): void {
  keyword.value = ''
  page.value = 1
  void loadDiaries()
}

function onSizeChange(): void {
  page.value = 1
  void loadDiaries()
}

function goBack(): void {
  void router.push('/diaries')
}

/* ===== 操作 ===== */

function openDetail(row: DiaryRow): void {
  detail.value = row
  detailVisible.value = true
}

/** 删除后若当前页被删空，回退一页，避免停在空白页 */
async function reloadAfterDelete(): Promise<void> {
  if (rows.value.length <= selected.value.length && page.value > 1) {
    page.value -= 1
  }
  await loadDiaries()
  // 日记数变了，头部计数一并刷新
  void loadUser()
}

async function onDelete(row: DiaryRow): Promise<void> {
  try {
    await ElMessageBox.confirm(
      `确定删除「${userName.value}」的日记「${row.title || row.id}」？此操作不可恢复。`,
      '危险操作',
      { type: 'warning', confirmButtonText: '删除' },
    )
    await deleteDiary(row.id)
    ElMessage.success('删除成功')
    selected.value = [row]
    await reloadAfterDelete()
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
    await ElMessageBox.confirm(
      `确定删除「${userName.value}」的 ${ids.length} 篇日记？此操作不可恢复。`,
      '危险操作',
      { type: 'warning', confirmButtonText: '删除' },
    )
    const res = await batchOperate('diary', 'delete', ids)
    ElMessage.success(`已删除 ${res?.affected ?? ids.length} 篇日记`)
    await reloadAfterDelete()
  } catch {
    /* 取消或已提示 */
  }
}

/** 导出当前用户「按当前搜索条件」的全部日记（逐页拉取，不是只导当前页） */
async function onExportAll(): Promise<void> {
  try {
    const pageSize = 100
    const collected: DiaryRow[] = []
    let current = 1

    // 上限 50 页 = 5000 条，防止异常数据把浏览器拖死
    for (; current <= 50; current++) {
      const res = await fetchDiaries({
        page: current,
        size: pageSize,
        keyword: keyword.value || undefined,
        userId,
      })
      const batch = res.records ?? []
      collected.push(...batch)
      if (batch.length < pageSize) break
    }

    if (!collected.length) {
      ElMessage.warning('没有可导出的数据')
      return
    }

    const header = ['ID', '用户', '标题', '内容', '情绪', '强度', '创建时间']
    const data = collected.map((row) => [
      row.id,
      userName.value,
      row.title || '',
      (row.content || '').replace(/\s+/g, ' '),
      row.emotion || '',
      row.intensity ?? '',
      formatTime(row.createTime),
    ])
    exportCsv(csvFilename(`日记_${userName.value}`), header, data)
    ElMessage.success(`已导出 ${data.length} 条记录`)
  } catch {
    /* 拦截器已提示 */
  }
}

onMounted(async () => {
  await Promise.all([loadUser(), loadDiaries()])
})
</script>

<template>
  <div class="page">
    <!-- 返回 + 用户画像 -->
    <div class="panel">
      <div class="back-row">
        <el-button link type="primary" @click="goBack">
          <el-icon><ArrowLeft /></el-icon>返回用户列表
        </el-button>
      </div>

      <div v-loading="userLoading" class="hero">
        <template v-if="userDetail">
          <div class="hero-avatar">{{ userInitial }}</div>
          <div class="hero-main">
            <div class="hero-name">{{ userName }}</div>
            <div class="hero-sub mono">
              {{ userDetail.user.phone || '无手机号' }}
              <span class="dot-sep">·</span>
              注册于 {{ formatTime(userDetail.user.createTime) }}
            </div>
            <div class="hero-tags">
              <el-tag
                :type="userDetail.user.isHuaweiUser ? 'success' : 'info'"
                size="small"
                effect="dark"
              >
                {{ userDetail.user.isHuaweiUser ? '华为账号' : '手机号注册' }}
              </el-tag>
              <el-tag
                :type="userDetail.user.deleted === 1 ? 'danger' : 'success'"
                size="small"
                effect="dark"
              >
                {{ userDetail.user.deleted === 1 ? '已禁用' : '正常' }}
              </el-tag>
              <el-tag size="small" effect="plain">共 {{ userDiaryCount }} 篇日记</el-tag>
            </div>
          </div>
        </template>
        <div v-else-if="!userLoading" class="hero-empty">未获取到该用户信息</div>
      </div>
    </div>

    <!-- 日记列表 -->
    <div class="panel">
      <div class="panel__head">
        <el-input
          v-model="keyword"
          class="search"
          placeholder="在该用户日记中搜索标题或内容"
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
        <el-button :loading="loading" @click="loadDiaries">
          <el-icon><Refresh /></el-icon>刷新
        </el-button>
        <el-button @click="onExportAll">
          <el-icon><Download /></el-icon>导出全部
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
        <el-table-column label="标题" min-width="160">
          <template #default="{ row }">{{ row.title || '-' }}</template>
        </el-table-column>
        <el-table-column label="内容" min-width="300">
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
          <el-empty
            :description="keyword ? '该用户没有匹配的日记' : '该用户还没有写过日记'"
            :image-size="80"
          />
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
          @current-change="loadDiaries"
          @size-change="onSizeChange"
        />
      </div>
    </div>

    <el-dialog v-model="detailVisible" title="日记详情" width="620px" align-center>
      <div v-if="detail" class="detail">
        <div class="detail-title">{{ detail.title || '（无标题）' }}</div>
        <div class="detail-meta">
          <span>{{ userName }}</span>
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
.back-row {
  padding: 12px 18px 0;
}

.search {
  width: 260px;
}

/* ===== 用户画像 ===== */
.hero {
  display: flex;
  align-items: center;
  gap: 14px;
  min-height: 96px;
  padding: 16px 18px 18px;
}

.hero-avatar {
  width: 54px;
  height: 54px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
  font-weight: 600;
  color: #fff;
  background: linear-gradient(135deg, #4d7cfe 0%, #8b7cff 100%);
  box-shadow: 0 10px 24px -10px rgba(77, 124, 254, 0.9);
  flex: none;
}

.hero-main {
  min-width: 0;
}

.hero-name {
  font-size: 17px;
  font-weight: 600;
  color: var(--text-1);
}

.hero-sub {
  margin-top: 2px;
  font-size: 12px;
  color: var(--text-3);
}

.dot-sep {
  margin: 0 6px;
  opacity: 0.5;
}

.hero-tags {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
}

.hero-empty {
  font-size: 13px;
  color: var(--text-3);
}

/* ===== 批量条 ===== */
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

/* ===== 详情弹窗 ===== */
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
