<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import {
  fetchAssessmentResults,
  type AssessmentAiAnalysis,
  type AssessmentAnswerDetail,
  type AssessmentResultRow,
} from '../api/admin'
import { formatTime } from '../utils/format'

const route = useRoute()

const loading = ref(false)
const keyword = ref('')
const userIdFilter = ref<number | null>(null)
const page = ref(1)
const size = ref(10)
const total = ref(0)
const rows = ref<AssessmentResultRow[]>([])

const detailVisible = ref(false)
const detail = ref<AssessmentResultRow | null>(null)

const filteredByUser = computed(() => userIdFilter.value !== null)

async function load(): Promise<void> {
  loading.value = true
  try {
    const res = await fetchAssessmentResults({
      page: page.value,
      size: size.value,
      keyword: keyword.value || undefined,
      userId: userIdFilter.value ?? undefined,
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
  userIdFilter.value = null
  page.value = 1
  void load()
}

function onSizeChange(): void {
  page.value = 1
  void load()
}

function openDetail(row: AssessmentResultRow): void {
  detail.value = row
  detailVisible.value = true
}

/* ===== 明细解析：后端存的是 JSON 字符串 ===== */

function parseAnswers(raw: string | null): AssessmentAnswerDetail[] {
  if (!raw) return []
  try {
    const parsed = JSON.parse(raw)
    return Array.isArray(parsed) ? (parsed as AssessmentAnswerDetail[]) : []
  } catch {
    return []
  }
}

function parseAi(raw: string | null): AssessmentAiAnalysis | null {
  if (!raw) return null
  try {
    return JSON.parse(raw) as AssessmentAiAnalysis
  } catch {
    return null
  }
}

const detailAnswers = computed<AssessmentAnswerDetail[]>(() => parseAnswers(detail.value?.answersJson ?? null))
const detailAi = computed<AssessmentAiAnalysis | null>(() => parseAi(detail.value?.aiAnalysis ?? null))

function scorePercent(row: AssessmentResultRow | null): number {
  if (!row || !row.score || !row.maxScore) return 0
  return Math.min(100, Math.round((row.score / row.maxScore) * 100))
}

function aiTagType(status: string | null): 'success' | 'warning' | 'danger' | 'info' {
  if (status === 'success') return 'success'
  if (status === 'failed') return 'danger'
  if (status === 'pending') return 'warning'
  return 'info'
}

function aiTagLabel(status: string | null): string {
  if (status === 'success') return '已生成'
  if (status === 'failed') return '生成失败'
  if (status === 'pending') return '生成中'
  return '无'
}

function riskLabel(risk: string | undefined): string {
  if (risk === 'high') return '需重点关注'
  if (risk === 'medium') return '需留意'
  return '整体平稳'
}

function levelTagType(level: string | null): 'success' | 'warning' | 'danger' | 'info' {
  if (!level) return 'info'
  if (level.indexOf('良好') >= 0 || level.indexOf('平稳') >= 0 || level.indexOf('较低') >= 0) return 'success'
  if (level.indexOf('明显') >= 0 || level.indexOf('较重') >= 0 || level.indexOf('过载') >= 0 || level.indexOf('较差') >= 0) {
    return 'danger'
  }
  return 'warning'
}

onMounted(() => {
  // 支持从用户详情跳进来时带 userId，直接聚焦某个人的记录
  const raw = route.query.userId
  if (raw) {
    const parsed = Number(raw)
    if (!Number.isNaN(parsed)) {
      userIdFilter.value = parsed
    }
  }
  void load()
})
</script>

<template>
  <div class="page">
    <div class="panel">
      <div class="panel__head">
        <el-input
          v-model="keyword"
          class="search"
          placeholder="搜索量表名称或等级"
          clearable
          @keyup.enter="onSearch"
        >
          <template #prefix>
            <el-icon><Search /></el-icon>
          </template>
        </el-input>
        <el-button type="primary" @click="onSearch">查询</el-button>
        <el-button @click="onReset">重置</el-button>
        <el-tag v-if="filteredByUser" type="info" effect="dark" closable @close="onReset">
          已按用户筛选 #{{ userIdFilter }}
        </el-tag>
        <div class="spacer" />
        <el-button :loading="loading" @click="load">
          <el-icon><Refresh /></el-icon>刷新
        </el-button>
      </div>

      <el-table v-loading="loading" :data="rows">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="用户" width="150">
          <template #default="{ row }">
            <span class="strong">{{ row.author || `#${row.userId}` }}</span>
          </template>
        </el-table-column>
        <el-table-column label="量表" min-width="150">
          <template #default="{ row }">{{ row.assessmentTitle || '-' }}</template>
        </el-table-column>
        <el-table-column label="得分" width="180">
          <template #default="{ row }">
            <div class="score-cell">
              <span class="score-text">
                <b>{{ row.score ?? '-' }}</b>
                <span class="score-max">/ {{ row.maxScore ?? '-' }}</span>
              </span>
              <div class="score-bar">
                <div class="score-bar__fill" :style="{ width: `${scorePercent(row)}%` }" />
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="等级" width="120">
          <template #default="{ row }">
            <el-tag :type="levelTagType(row.level)" size="small" effect="light">
              {{ row.level || '-' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="AI 解读" width="110">
          <template #default="{ row }">
            <el-tag :type="aiTagType(row.aiStatus)" size="small" effect="dark">
              {{ aiTagLabel(row.aiStatus) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="测评时间" width="170">
          <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="110" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row)">查看明细</el-button>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="暂无测评记录" :image-size="80" />
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

    <el-dialog v-model="detailVisible" title="测评明细" width="720px" align-center top="6vh">
      <div v-if="detail" class="detail">
        <div class="hero">
          <div class="hero-main">
            <div class="hero-name">
              {{ detail.assessmentTitle || '未命名量表' }}
              <el-tag :type="levelTagType(detail.level)" size="small" effect="dark">
                {{ detail.level || '未知' }}
              </el-tag>
            </div>
            <div class="hero-sub">
              {{ detail.author || `#${detail.userId}` }} · {{ formatTime(detail.createTime) }}
            </div>
          </div>
          <div class="hero-score">
            <div class="hero-score-value">{{ detail.score ?? '-' }}</div>
            <div class="hero-score-max">/ {{ detail.maxScore ?? '-' }}</div>
          </div>
        </div>

        <div class="block">
          <div class="block__title">逐题作答</div>
          <el-empty v-if="!detailAnswers.length" description="本次提交未记录答题明细（旧版本客户端）" :image-size="60" />
          <ul v-else class="answers">
            <li v-for="(item, index) in detailAnswers" :key="item.questionId">
              <span class="answers__index">{{ index + 1 }}</span>
              <span class="answers__title">{{ item.title }}</span>
              <span class="answers__value">
                {{ item.optionText || '未作答' }}
                <b>{{ item.score }}<i>/{{ item.maxScore }}</i></b>
              </span>
            </li>
          </ul>
        </div>

        <div class="block">
          <div class="block__title">规则基线建议</div>
          <div class="text-box">{{ detail.suggestion || '（无）' }}</div>
        </div>

        <div class="block">
          <div class="block__title">
            AI 深度解读
            <el-tag :type="aiTagType(detail.aiStatus)" size="small" effect="dark">
              {{ aiTagLabel(detail.aiStatus) }}
            </el-tag>
          </div>

          <div v-if="detail.aiStatus === 'failed'" class="text-box muted">
            {{ detail.aiError || 'AI 解读生成失败' }}
          </div>
          <div v-else-if="!detailAi" class="text-box muted">AI 解读尚未生成（提交后由服务端异步生成）</div>
          <template v-else>
            <div v-if="detailAi.summary" class="ai-summary">{{ detailAi.summary }}</div>

            <ul v-if="detailAi.dimensions && detailAi.dimensions.length" class="dims">
              <li v-for="(dim, index) in detailAi.dimensions" :key="`dim-${index}`">
                <span class="dims__name">{{ dim.name || '-' }}</span>
                <span class="dims__level">{{ dim.level || '-' }}</span>
                <span class="dims__comment">{{ dim.comment || '' }}</span>
              </li>
            </ul>

            <div v-if="detailAi.trend" class="ai-line">
              <span class="ai-line__label">变化趋势</span>
              <span class="ai-line__value">{{ detailAi.trend }}</span>
            </div>

            <ul v-if="detailAi.suggestions && detailAi.suggestions.length" class="sugs">
              <li v-for="(sug, index) in detailAi.suggestions" :key="`sug-${index}`">
                <div class="sugs__title">{{ sug.title }}</div>
                <div class="sugs__detail">{{ sug.detail }}</div>
              </li>
            </ul>

            <div class="ai-foot">
              <span>风险等级：{{ riskLabel(detailAi.riskLevel) }}</span>
              <span v-if="detailAi.needProfessionalHelp" class="ai-foot__warn">建议寻求专业支持</span>
              <span v-if="detailAi.model" class="ai-foot__model">{{ detailAi.model }}</span>
            </div>
          </template>
        </div>
      </div>
      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.search {
  width: 260px;
}

.strong {
  font-weight: 600;
  color: var(--text-1);
}

/* ===== 得分列 ===== */
.score-cell {
  display: flex;
  flex-direction: column;
  gap: 5px;
}

.score-text b {
  font-size: 14px;
  color: var(--text-1);
  font-variant-numeric: tabular-nums;
}

.score-max {
  margin-left: 3px;
  font-size: 11px;
  color: var(--text-3);
}

.score-bar {
  height: 4px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.08);
  overflow: hidden;
}

.score-bar__fill {
  height: 100%;
  border-radius: 999px;
  background: linear-gradient(90deg, #4d7cfe 0%, #8b7cff 100%);
}

/* ===== 明细弹窗 ===== */
.hero {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  border-radius: var(--radius);
  background: linear-gradient(135deg, rgba(77, 124, 254, 0.14) 0%, rgba(34, 211, 197, 0.07) 100%);
  border: 1px solid var(--border);
}

.hero-main {
  flex: 1;
  min-width: 0;
}

.hero-name {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 16px;
  font-weight: 600;
  color: var(--text-1);
}

.hero-sub {
  margin-top: 4px;
  font-size: 12px;
  color: var(--text-3);
}

.hero-score {
  display: flex;
  align-items: baseline;
  gap: 2px;
  flex: none;
}

.hero-score-value {
  font-size: 30px;
  font-weight: 700;
  color: var(--text-1);
  font-variant-numeric: tabular-nums;
}

.hero-score-max {
  font-size: 13px;
  color: var(--text-3);
}

.block {
  margin-top: 20px;
}

.block__title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 10px;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-2);
}

.text-box {
  padding: 12px 14px;
  font-size: 13px;
  line-height: 1.8;
  color: var(--text-2);
  background: var(--surface-muted);
  border-radius: var(--radius-sm);
  white-space: pre-wrap;
  word-break: break-word;
}

.text-box.muted {
  color: var(--text-3);
}

/* ===== 逐题作答 ===== */
.answers {
  margin: 0;
  padding: 0;
  list-style: none;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  overflow: hidden;
  max-height: 300px;
  overflow-y: auto;
}

.answers li {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 12px;
  font-size: 13px;
  border-bottom: 1px solid var(--border);
}

.answers li:last-child {
  border-bottom: none;
}

.answers__index {
  width: 20px;
  flex: none;
  font-size: 11px;
  color: var(--text-3);
  font-variant-numeric: tabular-nums;
}

.answers__title {
  flex: 1;
  min-width: 0;
  color: var(--text-2);
}

.answers__value {
  flex: none;
  font-size: 12px;
  color: var(--text-3);
}

.answers__value b {
  margin-left: 6px;
  color: var(--brand-300);
}

.answers__value i {
  font-style: normal;
  opacity: 0.6;
}

/* ===== AI 内容 ===== */
.ai-summary {
  padding: 12px 14px;
  font-size: 14px;
  line-height: 1.8;
  color: var(--text-1);
  background: rgba(77, 124, 254, 0.08);
  border-left: 3px solid var(--brand-400);
  border-radius: var(--radius-sm);
}

.dims {
  margin: 14px 0 0;
  padding: 0;
  list-style: none;
}

.dims li {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 8px 0;
  font-size: 13px;
  border-bottom: 1px dashed var(--border);
}

.dims li:last-child {
  border-bottom: none;
}

.dims__name {
  width: 88px;
  flex: none;
  font-weight: 600;
  color: var(--text-1);
}

.dims__level {
  flex: none;
  padding: 1px 8px;
  font-size: 11px;
  color: var(--brand-300);
  background: rgba(77, 124, 254, 0.14);
  border-radius: 6px;
}

.dims__comment {
  flex: 1;
  min-width: 0;
  color: var(--text-2);
  line-height: 1.7;
}

.ai-line {
  display: flex;
  gap: 10px;
  margin-top: 12px;
  font-size: 13px;
}

.ai-line__label {
  width: 88px;
  flex: none;
  color: var(--text-3);
}

.ai-line__value {
  flex: 1;
  min-width: 0;
  color: var(--text-2);
  line-height: 1.7;
}

.sugs {
  margin: 14px 0 0;
  padding: 0;
  list-style: none;
}

.sugs li {
  padding: 10px 0;
  border-bottom: 1px dashed var(--border);
}

.sugs li:last-child {
  border-bottom: none;
}

.sugs__title {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
}

.sugs__detail {
  margin-top: 3px;
  font-size: 13px;
  line-height: 1.75;
  color: var(--text-2);
}

.ai-foot {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-top: 14px;
  padding-top: 12px;
  font-size: 12px;
  color: var(--text-3);
  border-top: 1px solid var(--border);
}

.ai-foot__warn {
  color: #f5c860;
}

.ai-foot__model {
  margin-left: auto;
  opacity: 0.7;
}
</style>
