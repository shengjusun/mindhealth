<template>
  <div class="page">
    <div class="container">
      <RouterLink to="/me" class="back">
        <AppIcon name="arrow-left" :size="16" />
        返回我的
      </RouterLink>

      <header class="head">
        <h1 class="head__title">我的记录</h1>
        <p class="head__sub">心情和状态都在这里慢慢积累，回头看会看到自己的变化。</p>
      </header>

      <div class="tabs">
        <button
          type="button"
          class="tab"
          :class="{ 'tab--active': tab === 'diary' }"
          @click="tab = 'diary'"
        >
          <AppIcon name="edit" :size="16" />
          情绪日记
          <span class="tab__count">{{ diaries.length }}</span>
        </button>
        <button
          type="button"
          class="tab"
          :class="{ 'tab--active': tab === 'assessment' }"
          @click="tab = 'assessment'"
        >
          <AppIcon name="clipboard" :size="16" />
          状态测评
          <span class="tab__count">{{ results.length }}</span>
        </button>
      </div>

      <div v-if="loading" class="list">
        <div v-for="i in 4" :key="i" class="item item--skeleton">
          <AppSkeleton height="13px" width="32%" />
          <AppSkeleton height="16px" width="62%" />
        </div>
      </div>

      <!-- 日记 -->
      <template v-else-if="tab === 'diary'">
        <AppEmpty
          v-if="diaries.length === 0"
          icon="edit"
          title="还没有日记"
          description="写下第一篇，之后回看会很有意义"
        >
          <template #action>
            <AppButton @click="router.push('/diary/new')">写第一篇</AppButton>
          </template>
        </AppEmpty>

        <div v-else class="list">
          <RouterLink v-for="d in diaries" :key="d.id" :to="`/diary/${d.id}`" class="item">
            <div class="item__top">
              <AppTag :kind="emotionKind(d.emotion)" size="sm">{{ emotionEmoji(d.emotion) }} {{ d.emotion }}</AppTag>
              <span class="item__time">{{ formatDateTime(d.createTime) }}</span>
            </div>
            <span class="item__title">{{ d.title || '（未命名）' }}</span>
            <span class="item__excerpt">{{ excerpt(d.content) }}</span>
          </RouterLink>
        </div>
      </template>

      <!-- 测评 -->
      <template v-else>
        <AppEmpty
          v-if="results.length === 0"
          icon="clipboard"
          title="还没有测评记录"
          description="花几分钟认识一下此刻的自己"
        >
          <template #action>
            <AppButton @click="router.push('/assessment')">开始自查</AppButton>
          </template>
        </AppEmpty>

        <div v-else class="list">
          <RouterLink
            v-for="r in results"
            :key="r.id"
            :to="`/assessment/result/${r.id}`"
            class="item"
          >
            <div class="item__top">
              <span class="item__title">{{ r.assessmentTitle }}</span>
              <span class="item__time">{{ formatDateTime(r.createTime) }}</span>
            </div>
            <div class="item__bottom">
              <AppTag :kind="softLevelKind(r.level)" size="sm">{{ softLevel(r.level) }}</AppTag>
              <span class="item__score">{{ r.score }}<i>/{{ r.maxScore }}</i></span>
            </div>
          </RouterLink>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { listDiaries } from '../../api/diary'
import { fetchResults } from '../../api/assessment'
import type { AssessmentResult, Diary } from '../../api/types'
import {
  emotionEmoji,
  emotionKind,
  formatDateTime,
  softLevel,
  softLevelKind,
} from '../../utils/format'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppEmpty from '../../components/ui/AppEmpty.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppSkeleton from '../../components/ui/AppSkeleton.vue'
import AppTag from '../../components/ui/AppTag.vue'

const router = useRouter()

const tab = ref<'diary' | 'assessment'>('diary')
const diaries = ref<Diary[]>([])
const results = ref<AssessmentResult[]>([])
const loading = ref(true)

function excerpt(content: string): string {
  const text = (content || '').replace(/\s+/g, ' ').trim()
  if (!text) return '（这篇还没有正文）'
  return text.length > 80 ? `${text.slice(0, 80)}…` : text
}

onMounted(async () => {
  const [d, r] = await Promise.allSettled([listDiaries(), fetchResults()])
  if (d.status === 'fulfilled') {
    diaries.value = d.value ?? []
  } else {
    const err = d.reason
    toast.error(err instanceof Error && err.message ? err.message : '日记加载失败')
  }
  if (r.status === 'fulfilled') results.value = r.value ?? []
  loading.value = false
})
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-4xl);
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
.head {
  margin: var(--space-l) 0 var(--space-2xl);
}
.head__title {
  font-size: clamp(24px, 3.2vw, 32px);
}
.head__sub {
  margin-top: var(--space-s);
  font-size: var(--font-m);
  color: var(--text-3);
}

.tabs {
  display: inline-flex;
  gap: 4px;
  padding: 4px;
  border-radius: var(--radius-full);
  background: var(--bg-soft);
  border: 1px solid var(--line);
  margin-bottom: var(--space-2xl);
}
.tab {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 38px;
  padding: 0 18px;
  border: none;
  border-radius: var(--radius-full);
  background: transparent;
  color: var(--text-2);
  font-size: var(--font-m);
  cursor: pointer;
  transition:
    background-color var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard);
}
.tab--active {
  background: var(--card);
  color: var(--primary);
  font-weight: 600;
  box-shadow: var(--shadow-sm);
}
.tab__count {
  font-size: var(--font-xs);
  color: var(--text-3);
}
.tab--active .tab__count {
  color: var(--primary);
}

.list {
  display: flex;
  flex-direction: column;
  gap: var(--space-l);
}
.item {
  display: flex;
  flex-direction: column;
  gap: var(--space-s);
  padding: var(--space-l) var(--space-2xl);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
  transition:
    transform var(--motion-normal) var(--ease-emphasized),
    border-color var(--motion-normal) var(--ease-standard),
    box-shadow var(--motion-normal) var(--ease-standard);
}
.item:not(.item--skeleton):hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.item--skeleton {
  gap: var(--space-m);
  box-shadow: none;
}
.item__top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
}
.item__bottom {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
}
.item__title {
  font-size: var(--font-l);
  font-weight: 600;
}
.item__time {
  font-size: var(--font-xs);
  color: var(--text-3);
  white-space: nowrap;
}
.item__excerpt {
  font-size: var(--font-m);
  line-height: 1.8;
  color: var(--text-2);
}
.item__score {
  font-size: var(--font-xl);
  font-weight: 700;
  color: var(--primary);
  line-height: 1;
}
.item__score i {
  font-size: var(--font-2xs);
  font-style: normal;
  font-weight: 500;
  color: var(--text-3);
}
</style>
