<template>
  <div class="page">
    <div class="container">
      <header class="page__head">
        <AppTag kind="primary" icon="clipboard" size="md">状态自查</AppTag>
        <h1 class="page__title">花几分钟，认识一下此刻的自己</h1>
        <p class="page__sub">
          结果仅供参考，不能替代专业诊断。自查只是帮你把感受看得更清楚一点。
        </p>
      </header>

      <section class="section">
        <h2 class="section__title">可做的自查</h2>
        <div v-if="loading" class="grid">
          <div v-for="i in 3" :key="i" class="scale scale--skeleton">
            <AppSkeleton height="18px" width="52%" />
            <AppSkeleton height="13px" width="100%" />
            <AppSkeleton height="13px" width="70%" />
          </div>
        </div>

        <AppEmpty
          v-else-if="scales.length === 0"
          icon="clipboard"
          title="暂时没有可做的量表"
          description="量表正在维护，稍后再来看看"
        />

        <div v-else class="grid">
          <article v-for="(s, i) in scales" :key="s.id" class="scale" v-reveal="i * 80">
            <div class="scale__top">
              <AppIcon name="clipboard" :size="18" />
              <span class="scale__version">v{{ s.version }}</span>
            </div>
            <h3 class="scale__name">{{ s.name }}</h3>
            <p class="scale__desc">{{ s.description || '一份帮助你了解自己的小问卷。' }}</p>
            <div class="scale__meta">
              <span>{{ s.questionCount }} 题</span>
              <span class="scale__dot">·</span>
              <span>约 {{ Math.max(1, Math.round(s.questionCount / 2)) }} 分钟</span>
            </div>
            <AppButton block icon="arrow-right" @click="start(s.id)">开始测评</AppButton>
          </article>
        </div>
      </section>

      <section v-if="results.length > 0" class="section">
        <div class="section__bar">
          <h2 class="section__title">最近的记录</h2>
          <RouterLink to="/me/records" class="section__more">
            全部记录 <AppIcon name="chevron-right" :size="14" />
          </RouterLink>
        </div>
        <div class="records">
          <RouterLink
            v-for="r in results.slice(0, 4)"
            :key="r.id"
            :to="`/assessment/result/${r.id}`"
            class="record"
          >
            <div class="record__left">
              <span class="record__name">{{ r.assessmentTitle }}</span>
              <span class="record__time">{{ formatDateTime(r.createTime) }}</span>
            </div>
            <div class="record__right">
              <AppTag :kind="softLevelKind(r.level)" size="sm">{{ softLevel(r.level) }}</AppTag>
              <span class="record__score">{{ r.score }}<i>/{{ r.maxScore }}</i></span>
            </div>
          </RouterLink>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { fetchManifest, fetchResults } from '../../api/assessment'
import type { AssessmentResult, ManifestScale } from '../../api/types'
import { formatDateTime, softLevel, softLevelKind } from '../../utils/format'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppEmpty from '../../components/ui/AppEmpty.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppSkeleton from '../../components/ui/AppSkeleton.vue'
import AppTag from '../../components/ui/AppTag.vue'

const router = useRouter()

const scales = ref<ManifestScale[]>([])
const results = ref<AssessmentResult[]>([])
const loading = ref(true)

function start(id: number): void {
  router.push(`/assessment/${id}`)
}

onMounted(async () => {
  // 记录失败不阻塞量表展示
  const [manifest, list] = await Promise.allSettled([fetchManifest(), fetchResults()])
  if (manifest.status === 'fulfilled') {
    scales.value = manifest.value.scales ?? []
  } else {
    const err = manifest.reason
    toast.error(err instanceof Error && err.message ? err.message : '量表加载失败')
  }
  if (list.status === 'fulfilled') results.value = list.value ?? []
  loading.value = false
})
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-4xl);
}
.page__head {
  max-width: 640px;
}
.page__title {
  margin-top: var(--space-l);
  font-size: clamp(24px, 3.2vw, 34px);
}
.page__sub {
  margin-top: var(--space-m);
  font-size: var(--font-l);
  line-height: 1.9;
  color: var(--text-2);
}

.section {
  margin-top: var(--space-3xl);
}
.section__bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
}
.section__title {
  font-size: var(--font-2xl);
}
.section__more {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  font-size: var(--font-s);
  color: var(--primary);
}

.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-l);
  margin-top: var(--space-l);
}
.scale {
  display: flex;
  flex-direction: column;
  gap: var(--space-s);
  padding: var(--space-2xl);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
  transition:
    transform var(--motion-normal) var(--ease-emphasized),
    border-color var(--motion-normal) var(--ease-standard),
    box-shadow var(--motion-normal) var(--ease-standard);
}
.scale:not(.scale--skeleton):hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.scale--skeleton {
  gap: var(--space-l);
}
.scale__top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: var(--primary);
}
.scale__version {
  font-size: var(--font-xs);
  color: var(--text-3);
}
.scale__name {
  font-size: var(--font-xl);
}
.scale__desc {
  flex: 1;
  font-size: var(--font-m);
  line-height: 1.85;
  color: var(--text-2);
}
.scale__meta {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-xs);
  color: var(--text-3);
}
.scale__dot {
  opacity: 0.6;
}

.records {
  display: flex;
  flex-direction: column;
  gap: var(--space-s);
  margin-top: var(--space-l);
}
.record {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
  padding: var(--space-l) var(--space-xl);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
  transition:
    transform var(--motion-normal) var(--ease-emphasized),
    border-color var(--motion-normal) var(--ease-standard),
    box-shadow var(--motion-normal) var(--ease-standard);
}
.record:hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.record__left {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.record__name {
  font-size: var(--font-l);
  font-weight: 600;
}
.record__time {
  font-size: var(--font-xs);
  color: var(--text-3);
}
.record__right {
  display: inline-flex;
  align-items: center;
  gap: var(--space-m);
}
.record__score {
  font-size: var(--font-2xl);
  font-weight: 700;
  color: var(--primary);
  line-height: 1;
}
.record__score i {
  font-size: var(--font-xs);
  font-style: normal;
  font-weight: 500;
  color: var(--text-3);
}

@media (max-width: 1000px) {
  .grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
@media (max-width: 640px) {
  .grid {
    grid-template-columns: 1fr;
  }
}
</style>
