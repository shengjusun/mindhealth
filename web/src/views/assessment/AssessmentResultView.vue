<template>
  <div class="page">
    <div class="container container--result">
      <RouterLink to="/assessment" class="back">
        <AppIcon name="arrow-left" :size="16" />
        返回自查列表
      </RouterLink>

      <div v-if="loading" class="loading">
        <AppSpinner />
        <span>正在读取报告…</span>
      </div>

      <AppEmpty
        v-else-if="!result"
        icon="clipboard"
        title="这份报告找不到了"
        description="它可能已被删除，或者不属于当前账号"
      >
        <template #action>
          <AppButton kind="secondary" @click="router.replace('/assessment')">返回自查列表</AppButton>
        </template>
      </AppEmpty>

      <template v-else>
        <header class="head">
          <h1 class="head__title">{{ result.assessmentTitle }}</h1>
          <p class="head__time">测评时间 {{ formatDateTime(result.createTime) }}</p>
        </header>

        <section class="score">
          <div class="score__main">
            <span class="score__num">{{ result.score }}</span>
            <span class="score__total">/ {{ result.maxScore }}</span>
          </div>
          <div class="score__meta">
            <AppTag :kind="softLevelKind(result.level)" size="md">{{ softLevel(result.level) }}</AppTag>
            <p class="score__note">分数越高代表当前状态越稳定，仅作为自我观察的参考。</p>
          </div>
        </section>

        <section v-if="result.suggestion" class="card">
          <h2 class="card__title">
            <AppIcon name="sparkles" :size="17" />
            给你的小建议
          </h2>
          <p class="card__text">{{ result.suggestion }}</p>
        </section>

        <section class="card">
          <h2 class="card__title">
            <AppIcon name="leaf" :size="17" />
            AI 解读
          </h2>

          <div v-if="result.aiStatus === 'pending'" class="ai">
            <div v-if="polling.active" class="ai__pending">
              <span class="typing"><i></i><i></i><i></i></span>
              <span class="ai__pending-text">正在结合你的作答生成解读，请稍等…</span>
            </div>
            <div v-else class="ai__slow">
              <p class="ai__slow-text">{{ slowText }}</p>
              <AppButton size="sm" kind="secondary" icon="refresh" :loading="retrying" @click="retry">
                重新生成
              </AppButton>
            </div>
          </div>

          <div v-else-if="result.aiStatus === 'failed'" class="ai__slow">
            <p class="ai__slow-text">
              AI 解读这次没能生成成功{{ result.aiError ? `：${result.aiError}` : '' }}。可以再试一次。
            </p>
            <AppButton size="sm" kind="secondary" icon="refresh" :loading="retrying" @click="retry">
              重新生成
            </AppButton>
          </div>

          <div v-else-if="analysis" class="analysis">
            <p class="analysis__summary">{{ analysis.summary }}</p>

            <p v-if="analysis.trend" class="analysis__trend">
              <AppIcon name="wind" :size="15" />
              {{ analysis.trend }}
            </p>

            <div class="analysis__tags">
              <AppTag :kind="riskKind" size="sm">风险提示：{{ riskLabel(analysis.riskLevel) }}</AppTag>
            </div>

            <div v-if="analysis.dimensions && analysis.dimensions.length > 0" class="dims">
              <div v-for="(d, i) in analysis.dimensions" :key="i" class="dim">
                <div class="dim__head">
                  <span class="dim__name">{{ d.name }}</span>
                  <AppTag kind="plain" size="sm">{{ d.level }}</AppTag>
                </div>
                <p class="dim__comment">{{ d.comment }}</p>
              </div>
            </div>

            <div v-if="analysis.suggestions && analysis.suggestions.length > 0" class="suggests">
              <h3 class="suggests__title">接下来可以试试</h3>
              <div v-for="(s, i) in analysis.suggestions" :key="i" class="suggest">
                <span class="suggest__index">{{ i + 1 }}</span>
                <div>
                  <p class="suggest__title">{{ s.title }}</p>
                  <p class="suggest__detail">{{ s.detail }}</p>
                </div>
              </div>
            </div>

            <p v-if="analysis.model" class="analysis__model">由 {{ analysis.model }} 生成</p>
          </div>

          <p v-else class="card__text card__text--muted">
            这份报告还没有 AI 解读。你可以点下面按钮让它生成一份。
          </p>

          <div v-if="!analysis && result.aiStatus !== 'pending'" class="ai__retry">
            <AppButton size="sm" kind="secondary" icon="sparkles" :loading="retrying" @click="retry">
              生成 AI 解读
            </AppButton>
          </div>
        </section>

        <section v-if="showHelp" class="help">
          <AppIcon name="phone" :size="18" />
          <div>
            <p class="help__title">如果最近状态持续不好，请别一个人扛着</p>
            <p class="help__text">
              可以联系学校心理中心、正规心理咨询机构，或拨打全国心理援助热线
              <strong>12356</strong>（24 小时）。需要的时候求助，是很勇敢的事。
            </p>
          </div>
        </section>

        <footer class="foot">
          <AppButton kind="secondary" icon="plus" @click="router.push('/assessment')">再做一份</AppButton>
          <AppButton kind="ghost" icon="message" @click="router.push('/ai')">和树洞说说</AppButton>
        </footer>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { analyzeResult, fetchResult } from '../../api/assessment'
import type { AiAnalysis, AssessmentResult } from '../../api/types'
import { formatDateTime, parseJson, riskLabel, softLevel, softLevelKind } from '../../utils/format'
import { usePolling } from '../../composables/usePolling'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppEmpty from '../../components/ui/AppEmpty.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppSpinner from '../../components/ui/AppSpinner.vue'
import AppTag from '../../components/ui/AppTag.vue'

const route = useRoute()
const router = useRouter()

const result = ref<AssessmentResult | null>(null)
const loading = ref(true)
const retrying = ref(false)
const slowText = ref('正在结合你的作答生成解读，请稍等…')

const analysis = computed<AiAnalysis | null>(() => {
  const raw = result.value?.aiAnalysis
  if (!raw) return null
  return parseJson<AiAnalysis | null>(raw, null)
})

const riskKind = computed(() => {
  const risk = analysis.value?.riskLevel
  if (risk === 'high') return 'danger'
  if (risk === 'medium') return 'warning'
  return 'success'
})

const showHelp = computed(() => {
  const a = analysis.value
  if (a?.needProfessionalHelp) return true
  if (a?.riskLevel === 'high') return true
  return false
})

const polling = usePolling(
  async () => {
    const id = Number(route.params.id)
    const fresh = await fetchResult(id)
    result.value = fresh
    return fresh.aiStatus !== 'pending'
  },
  {
    interval: 2500,
    timeout: 90000,
    onTimeout: () => {
      slowText.value = '解读生成得有点慢，可能服务正忙。可以点「重新生成」，或稍后回来刷新查看。'
    },
    onError: () => {
      /* 单次失败继续重试，超时由 onTimeout 兜底 */
    },
  },
)

async function load(): Promise<void> {
  loading.value = true
  try {
    const data = await fetchResult(Number(route.params.id))
    result.value = data
    if (data.aiStatus === 'pending') polling.start()
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '报告加载失败')
  } finally {
    loading.value = false
  }
}

async function retry(): Promise<void> {
  if (retrying.value || !result.value) return
  retrying.value = true
  try {
    await analyzeResult(result.value.id)
    result.value.aiStatus = 'pending'
    slowText.value = '正在结合你的作答生成解读，请稍等…'
    polling.start()
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '生成失败，请稍后再试')
  } finally {
    retrying.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-4xl);
}
.container--result {
  max-width: 760px;
}
.back {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-m);
  color: var(--text-3);
  transition: color var(--motion-fast) var(--ease-standard);
}
.back:hover {
  color: var(--primary);
}
.loading {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-s);
  padding: var(--space-5xl, 56px) 0;
  color: var(--text-3);
  font-size: var(--font-m);
}

.head {
  margin: var(--space-l) 0 var(--space-2xl);
}
.head__title {
  font-size: clamp(22px, 3vw, 30px);
}
.head__time {
  margin-top: var(--space-s);
  font-size: var(--font-s);
  color: var(--text-3);
}

.score {
  display: flex;
  align-items: center;
  gap: var(--space-3xl);
  padding: var(--space-2xl) var(--space-3xl);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm), inset 0 1px 0 var(--glass-sheen);
  flex-wrap: wrap;
}
.score__main {
  display: flex;
  align-items: baseline;
  gap: 6px;
}
.score__num {
  font-size: 56px;
  font-weight: 800;
  line-height: 1;
  color: var(--primary);
}
.score__total {
  font-size: var(--font-l);
  color: var(--text-3);
}
.score__meta {
  display: flex;
  flex-direction: column;
  gap: var(--space-s);
  flex: 1;
  min-width: 200px;
}
.score__note {
  font-size: var(--font-s);
  line-height: 1.8;
  color: var(--text-2);
}

.card {
  margin-top: var(--space-l);
  padding: var(--space-2xl);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
}
.card__title {
  display: flex;
  align-items: center;
  gap: var(--space-s);
  font-size: var(--font-xl);
  color: var(--text);
}
.card__text {
  margin-top: var(--space-m);
  font-size: var(--font-m);
  line-height: 2;
  color: var(--text-2);
}
.card__text--muted {
  color: var(--text-3);
}

.ai {
  margin-top: var(--space-l);
}
.ai__pending {
  display: flex;
  align-items: center;
  gap: var(--space-m);
}
.ai__pending-text {
  font-size: var(--font-m);
  color: var(--text-3);
}
.typing {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 10px 14px;
  border-radius: var(--radius-full);
  background: var(--bg-soft);
  border: 1px solid var(--line);
}
.typing i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--text-3);
  animation: blink 1.2s infinite ease-in-out;
}
.typing i:nth-child(2) {
  animation-delay: 0.18s;
}
.typing i:nth-child(3) {
  animation-delay: 0.36s;
}
@keyframes blink {
  0%,
  60%,
  100% {
    opacity: 0.25;
    transform: translateY(0);
  }
  30% {
    opacity: 1;
    transform: translateY(-3px);
  }
}
.ai__slow {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--space-m);
}
.ai__slow-text {
  font-size: var(--font-m);
  line-height: 1.9;
  color: var(--text-2);
}
.ai__retry {
  margin-top: var(--space-l);
}

.analysis {
  margin-top: var(--space-l);
}
.analysis__summary {
  font-size: var(--font-m);
  line-height: 2.05;
  color: var(--text);
  white-space: pre-wrap;
}
.analysis__trend {
  display: flex;
  align-items: flex-start;
  gap: var(--space-s);
  margin-top: var(--space-l);
  padding: var(--space-m) var(--space-l);
  border-radius: var(--radius-md);
  background: var(--bg-soft);
  border: 1px solid var(--line);
  font-size: var(--font-m);
  line-height: 1.9;
  color: var(--text-2);
}
.analysis__tags {
  margin-top: var(--space-l);
}
.analysis__model {
  margin-top: var(--space-l);
  font-size: var(--font-2xs);
  color: var(--text-3);
}

.dims {
  display: flex;
  flex-direction: column;
  gap: var(--space-m);
  margin-top: var(--space-xl);
}
.dim {
  padding: var(--space-l);
  border-radius: var(--radius-md);
  background: var(--bg-soft);
  border: 1px solid var(--line);
}
.dim__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
}
.dim__name {
  font-size: var(--font-m);
  font-weight: 600;
}
.dim__comment {
  margin-top: var(--space-s);
  font-size: var(--font-s);
  line-height: 1.9;
  color: var(--text-2);
}

.suggests {
  margin-top: var(--space-xl);
}
.suggests__title {
  font-size: var(--font-m);
  font-weight: 700;
  color: var(--text-2);
}
.suggest {
  display: flex;
  gap: var(--space-m);
  margin-top: var(--space-m);
}
.suggest__index {
  flex: none;
  display: grid;
  place-items: center;
  width: 22px;
  height: 22px;
  border-radius: var(--radius-full);
  background: var(--primary-weak);
  color: var(--primary);
  font-size: var(--font-xs);
  font-weight: 700;
}
.suggest__title {
  font-size: var(--font-m);
  font-weight: 600;
}
.suggest__detail {
  margin-top: 4px;
  font-size: var(--font-s);
  line-height: 1.9;
  color: var(--text-2);
}

.help {
  display: flex;
  gap: var(--space-m);
  margin-top: var(--space-l);
  padding: var(--space-xl);
  border-radius: var(--radius-lg);
  background: var(--accent-weak);
  border: 1px solid var(--line-strong);
  box-shadow: var(--shadow-sm);
  color: var(--text);
}
.help__title {
  font-size: var(--font-m);
  font-weight: 700;
}
.help__text {
  margin-top: 6px;
  font-size: var(--font-s);
  line-height: 1.95;
  color: var(--text-2);
}
.help__text strong {
  color: var(--danger);
}

.foot {
  display: flex;
  gap: var(--space-m);
  margin-top: var(--space-3xl);
}
</style>
