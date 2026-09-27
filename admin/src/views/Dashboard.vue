<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import type { EChartsCoreOption } from 'echarts/core'
import EChart from '../components/EChart.vue'
import {
  fetchEmotionDistribution,
  fetchFeedbackTypes,
  fetchFeedbacks,
  fetchStats,
  fetchTrend,
  type AdminStats,
  type DistributionItem,
  type FeedbackRow,
  type TrendData,
} from '../api/admin'
import { formatTime } from '../utils/format'

const router = useRouter()

const loading = ref(false)
const stats = ref<AdminStats | null>(null)

const trendDays = ref(14)
const trendLoading = ref(false)
const trend = ref<TrendData | null>(null)

const emotionLoading = ref(false)
const emotion = ref<DistributionItem[]>([])

const typeLoading = ref(false)
const feedbackTypes = ref<DistributionItem[]>([])

const pendingLoading = ref(false)
const pending = ref<FeedbackRow[]>([])

interface Metric {
  label: string
  value: number | string
  icon: string
  tone: string
  /** 只有确实存在对应页面时才给跳转；没有明细页的指标不要假装能点进去 */
  to?: string
  /** 无明细页时的说明，替代「点了跳错地方」 */
  hint?: string
}

const metrics = computed<Metric[]>(() => [
  { label: '注册用户', value: stats.value?.userCount ?? '-', icon: 'User', tone: 'brand', to: '/users' },
  { label: '日记总数', value: stats.value?.diaryCount ?? '-', icon: 'Notebook', tone: 'violet', to: '/diaries' },
  // 这里原先跳「测评题库」，但那个数字是「用户做过的测评次数」，
  // 题库是题库、记录是记录，跳过去是两码事。后端暂无结果明细接口，先不跳。
  {
    label: '测评完成次数',
    value: stats.value?.assessmentResultCount ?? '-',
    icon: 'Document',
    tone: 'cyan',
    hint: '暂无明细页',
  },
  {
    label: '待处理反馈',
    value: stats.value?.feedbackUnhandled ?? '-',
    icon: 'BellFilled',
    tone: 'amber',
    to: '/feedback',
  },
  { label: '反馈总数', value: stats.value?.feedbackTotal ?? '-', icon: 'ChatDotRound', tone: 'slate', to: '/feedback' },
])

const AXIS_LABEL = '#6d7a90'
const SPLIT_LINE = 'rgba(255,255,255,0.055)'
const AXIS_LINE = 'rgba(255,255,255,0.1)'
const SERIES = ['#4d7cfe', '#22d3c5', '#8b7cff', '#f0b429', '#ff7a8a', '#5ad1ff']

const tooltipStyle = {
  backgroundColor: 'rgba(22,29,45,0.96)',
  borderColor: 'rgba(255,255,255,0.12)',
  borderWidth: 1,
  padding: [8, 12] as [number, number],
  textStyle: { color: '#e8eefb', fontSize: 12 },
  extraCssText: 'border-radius:10px;box-shadow:0 20px 46px -20px rgba(0,0,0,0.95);',
}

const trendOption = computed<EChartsCoreOption>(() => {
  const data = trend.value
  return {
    grid: { left: 8, right: 14, top: 42, bottom: 4, containLabel: true },
    tooltip: { trigger: 'axis', ...tooltipStyle, axisPointer: { type: 'line', lineStyle: { color: 'rgba(255,255,255,0.18)' } } },
    legend: {
      top: 0,
      right: 0,
      icon: 'roundRect',
      itemWidth: 9,
      itemHeight: 9,
      itemGap: 16,
      textStyle: { color: AXIS_LABEL, fontSize: 12 },
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: data?.labels ?? [],
      axisLine: { lineStyle: { color: AXIS_LINE } },
      axisTick: { show: false },
      axisLabel: { color: AXIS_LABEL, fontSize: 11 },
    },
    yAxis: {
      type: 'value',
      minInterval: 1,
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: { color: AXIS_LABEL, fontSize: 11 },
      splitLine: { lineStyle: { color: SPLIT_LINE } },
    },
    series: [
      {
        name: '新增用户',
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 5,
        showSymbol: false,
        data: data?.users ?? [],
        lineStyle: { width: 2, color: SERIES[0] },
        itemStyle: { color: SERIES[0] },
        areaStyle: {
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              { offset: 0, color: 'rgba(77,124,254,0.28)' },
              { offset: 1, color: 'rgba(77,124,254,0)' },
            ],
          },
        },
      },
      {
        name: '新增日记',
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 5,
        showSymbol: false,
        data: data?.diaries ?? [],
        lineStyle: { width: 2, color: SERIES[1] },
        itemStyle: { color: SERIES[1] },
        areaStyle: {
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              { offset: 0, color: 'rgba(34,211,197,0.22)' },
              { offset: 1, color: 'rgba(34,211,197,0)' },
            ],
          },
        },
      },
      {
        name: '新增反馈',
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 5,
        showSymbol: false,
        data: data?.feedbacks ?? [],
        lineStyle: { width: 2, color: SERIES[2] },
        itemStyle: { color: SERIES[2] },
      },
    ],
  }
})

function donutOption(source: DistributionItem[], unit: string): EChartsCoreOption {
  return {
    color: SERIES,
    tooltip: { trigger: 'item', ...tooltipStyle, formatter: `{b}<br/>{c} ${unit} · {d}%` },
    legend: {
      bottom: 0,
      left: 'center',
      icon: 'circle',
      itemWidth: 8,
      itemHeight: 8,
      itemGap: 14,
      textStyle: { color: AXIS_LABEL, fontSize: 12 },
    },
    series: [
      {
        type: 'pie',
        radius: ['52%', '74%'],
        center: ['50%', '44%'],
        avoidLabelOverlap: true,
        padAngle: 2,
        itemStyle: { borderColor: 'rgba(19,25,39,0.9)', borderWidth: 2, borderRadius: 4 },
        label: { show: false },
        labelLine: { show: false },
        emphasis: { scale: true, scaleSize: 6 },
        data: source.map((item) => ({ name: item.name, value: item.value })),
      },
    ],
  }
}

const emotionOption = computed<EChartsCoreOption>(() => donutOption(emotion.value, '篇'))
const feedbackTypeOption = computed<EChartsCoreOption>(() => donutOption(feedbackTypes.value, '条'))

async function loadStats(): Promise<void> {
  loading.value = true
  try {
    stats.value = await fetchStats()
  } catch {
    /* 拦截器已提示 */
  } finally {
    loading.value = false
  }
}

async function loadTrend(): Promise<void> {
  trendLoading.value = true
  try {
    trend.value = await fetchTrend(trendDays.value)
  } catch {
    /* 拦截器已提示 */
  } finally {
    trendLoading.value = false
  }
}

async function loadEmotion(): Promise<void> {
  emotionLoading.value = true
  try {
    emotion.value = await fetchEmotionDistribution()
  } catch {
    /* 拦截器已提示 */
  } finally {
    emotionLoading.value = false
  }
}

async function loadTypes(): Promise<void> {
  typeLoading.value = true
  try {
    feedbackTypes.value = await fetchFeedbackTypes()
  } catch {
    /* 拦截器已提示 */
  } finally {
    typeLoading.value = false
  }
}

async function loadPending(): Promise<void> {
  pendingLoading.value = true
  try {
    const res = await fetchFeedbacks({ page: 1, size: 5, handled: false })
    pending.value = res.records ?? []
  } catch {
    /* 拦截器已提示 */
  } finally {
    pendingLoading.value = false
  }
}

function refresh(): void {
  void loadStats()
  void loadTrend()
  void loadEmotion()
  void loadTypes()
  void loadPending()
}

onMounted(refresh)
</script>

<template>
  <div class="page">
    <div class="toolbar">
      <span class="text-muted">数据实时统计 · 点击卡片可进入对应模块</span>
      <div class="spacer" />
      <el-button :loading="loading" @click="refresh">
        <el-icon><Refresh /></el-icon>刷新
      </el-button>
    </div>

    <div class="metrics">
      <div
        v-for="m in metrics"
        :key="m.label"
        class="metric"
        :class="[`tone-${m.tone}`, { 'is-static': !m.to }]"
        @click="m.to && router.push(m.to)"
      >
        <div class="metric-icon">
          <el-icon :size="19"><component :is="m.icon" /></el-icon>
        </div>
        <div class="metric-label">{{ m.label }}</div>
        <div class="metric-value">{{ m.value }}</div>
        <div v-if="m.hint" class="metric-hint">{{ m.hint }}</div>
      </div>
    </div>

    <div class="panel">
      <div class="panel__head">
        <span class="panel__title">增长趋势</span>
        <div class="spacer" />
        <el-radio-group v-model="trendDays" size="small" @change="loadTrend">
          <el-radio-button :value="7">近 7 天</el-radio-button>
          <el-radio-button :value="14">近 14 天</el-radio-button>
          <el-radio-button :value="30">近 30 天</el-radio-button>
        </el-radio-group>
      </div>
      <div class="panel__body">
        <div v-loading="trendLoading" class="chart-wrap">
          <EChart :option="trendOption" height="288px" />
        </div>
      </div>
    </div>

    <div class="split">
      <div class="panel">
        <div class="panel__head">
          <span class="panel__title">情绪分布</span>
          <div class="spacer" />
          <span class="text-muted">来源：全部日记</span>
        </div>
        <div class="panel__body">
          <div v-loading="emotionLoading" class="chart-wrap">
            <el-empty v-if="!emotion.length" description="暂无情绪数据" :image-size="72" />
            <EChart v-else :option="emotionOption" height="272px" />
          </div>
        </div>
      </div>

      <div class="panel">
        <div class="panel__head">
          <span class="panel__title">反馈类型占比</span>
          <div class="spacer" />
          <span class="text-muted">来源：全部反馈</span>
        </div>
        <div class="panel__body">
          <div v-loading="typeLoading" class="chart-wrap">
            <el-empty v-if="!feedbackTypes.length" description="暂无反馈数据" :image-size="72" />
            <EChart v-else :option="feedbackTypeOption" height="272px" />
          </div>
        </div>
      </div>
    </div>

    <div class="panel">
      <div class="panel__head">
        <span class="panel__title">待处理反馈</span>
        <el-tag v-if="pending.length" type="warning" size="small" effect="dark">
          {{ pending.length }} 条
        </el-tag>
        <div class="spacer" />
        <el-button size="small" text type="primary" @click="router.push('/feedback')">
          查看全部
        </el-button>
      </div>
      <div class="panel__body flush">
        <div v-loading="pendingLoading" class="feed-wrap">
          <el-empty v-if="!pending.length" description="暂无待处理反馈" :image-size="76" />
          <ul v-else class="feed-list">
            <li v-for="item in pending" :key="item.id" class="feed-item">
              <div class="feed-dot" />
              <div class="feed-main">
                <div class="feed-top">
                  <span class="feed-author">{{ item.author || '匿名用户' }}</span>
                  <el-tag size="small" type="info" effect="dark">{{ item.type || '其他' }}</el-tag>
                  <span class="feed-time">{{ formatTime(item.createTime) }}</span>
                </div>
                <div class="feed-content text-clip">{{ item.content }}</div>
              </div>
              <el-button size="small" text type="primary" @click="router.push('/feedback')">
                去处理
              </el-button>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.metrics {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 14px;
}

.metric {
  position: relative;
  padding: 18px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm), var(--glow-line);
  backdrop-filter: blur(18px) saturate(150%);
  -webkit-backdrop-filter: blur(18px) saturate(150%);
  cursor: pointer;
  overflow: hidden;
  transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
}

.metric::after {
  content: '';
  position: absolute;
  right: -40px;
  top: -40px;
  width: 130px;
  height: 130px;
  border-radius: 50%;
  background: radial-gradient(circle, var(--tone-glow) 0%, transparent 70%);
  pointer-events: none;
}

.metric:hover {
  transform: translateY(-3px);
  border-color: var(--border-glow);
  box-shadow: var(--shadow-md), 0 0 0 1px rgba(122, 158, 255, 0.16);
}

/* 没有跳转目标的指标：不要给出「可以点」的假象 */
.metric.is-static {
  cursor: default;
}

.metric.is-static:hover {
  transform: none;
  border-color: var(--border);
  box-shadow: var(--shadow-sm), var(--glow-line);
}

.metric-hint {
  position: relative;
  margin-top: 6px;
  font-size: 11px;
  color: var(--text-3);
  opacity: 0.75;
}

.metric-icon {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  margin-bottom: 14px;
  border-radius: 11px;
  color: var(--tone-fg);
  background: var(--tone-bg);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.1);
}

.metric-label {
  position: relative;
  font-size: 13px;
  color: var(--text-3);
}

.metric-value {
  position: relative;
  margin-top: 2px;
  font-size: 27px;
  font-weight: 600;
  line-height: 1.25;
  letter-spacing: -0.5px;
  color: var(--text-1);
  font-variant-numeric: tabular-nums;
}

.tone-brand {
  --tone-fg: #93b4ff;
  --tone-bg: rgba(77, 124, 254, 0.16);
  --tone-glow: rgba(77, 124, 254, 0.22);
}

.tone-violet {
  --tone-fg: #b7aaff;
  --tone-bg: rgba(139, 124, 255, 0.16);
  --tone-glow: rgba(139, 124, 255, 0.2);
}

.tone-cyan {
  --tone-fg: #6fe3d7;
  --tone-bg: rgba(34, 211, 197, 0.14);
  --tone-glow: rgba(34, 211, 197, 0.18);
}

.tone-amber {
  --tone-fg: #f5c860;
  --tone-bg: rgba(240, 180, 41, 0.15);
  --tone-glow: rgba(240, 180, 41, 0.16);
}

.tone-slate {
  --tone-fg: #a3b0c6;
  --tone-bg: rgba(255, 255, 255, 0.07);
  --tone-glow: rgba(255, 255, 255, 0.08);
}

.split {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(340px, 1fr));
  gap: 16px;
}

.chart-wrap {
  min-height: 272px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
}

.chart-wrap > * {
  width: 100%;
}

.flush {
  padding: 0;
}

.feed-wrap {
  min-height: 120px;
}

.feed-list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.feed-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 18px;
  border-bottom: 1px solid var(--border);
  transition: background-color 0.16s ease;
}

.feed-item:hover {
  background: rgba(255, 255, 255, 0.025);
}

.feed-item:last-child {
  border-bottom: none;
}

.feed-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #f0b429;
  box-shadow: 0 0 0 3px rgba(240, 180, 41, 0.16);
  flex: none;
}

.feed-main {
  flex: 1;
  min-width: 0;
}

.feed-top {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 3px;
}

.feed-author {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
}

.feed-time {
  font-size: 12px;
  color: var(--text-3);
}

.feed-content {
  font-size: 13px;
  color: var(--text-2);
  max-width: 100%;
}
</style>
