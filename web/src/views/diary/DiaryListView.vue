<template>
  <div class="page">
    <div class="container">
      <header class="page__head">
        <div>
          <AppTag kind="primary" icon="edit" size="md">情绪日记</AppTag>
          <h1 class="page__title">今天的心情，也值得被记下来</h1>
          <p class="page__sub">不用写得好看，写下来就已经在照顾自己了。</p>
        </div>
        <AppButton icon="plus" @click="router.push('/diary/new')">写一篇</AppButton>
      </header>

      <div class="stats">
        <div class="stat">
          <span class="stat__num">{{ diaries.length }}</span>
          <span class="stat__label">累计篇数</span>
        </div>
        <div class="stat">
          <span class="stat__num">{{ dominantEmotion ? emotionEmoji(dominantEmotion) : '—' }}</span>
          <span class="stat__label">最常出现：{{ dominantEmotion || '暂无' }}</span>
        </div>
        <div class="stat">
          <span class="stat__num">{{ thisMonthCount }}</span>
          <span class="stat__label">本月记录</span>
        </div>
      </div>

      <div class="filters">
        <button
          type="button"
          class="pill"
          :class="{ 'pill--active': activeEmotion === '' }"
          @click="activeEmotion = ''"
        >
          全部
        </button>
        <button
          v-for="e in EMOTIONS"
          :key="e"
          type="button"
          class="pill"
          :class="{ 'pill--active': activeEmotion === e }"
          @click="activeEmotion = e"
        >
          {{ emotionEmoji(e) }} {{ e }}
        </button>
      </div>

      <div v-if="loading" class="list">
        <div v-for="i in 4" :key="i" class="item item--skeleton">
          <AppSkeleton height="16px" width="30%" />
          <AppSkeleton height="18px" width="60%" />
          <AppSkeleton height="13px" width="100%" />
        </div>
      </div>

      <AppEmpty
        v-else-if="visible.length === 0"
        icon="edit"
        title="这里还空着"
        :description="activeEmotion ? '换个心情看看，或者现在写一篇' : '写下第一篇，之后回看会很有意义'"
      >
        <template #action>
          <AppButton @click="router.push('/diary/new')">写第一篇</AppButton>
        </template>
      </AppEmpty>

      <div v-else class="list">
        <article v-for="(d, i) in visible" :key="d.id" class="item" v-reveal="i * 60">
          <div class="item__top">
            <AppTag :kind="emotionKind(d.emotion)" size="sm">
              {{ emotionEmoji(d.emotion) }} {{ d.emotion }}
            </AppTag>
            <span class="item__date">{{ formatDateTime(d.createTime) }}</span>
          </div>
          <h2 class="item__title" @click="open(d)">{{ d.title || '（未命名）' }}</h2>
          <p class="item__excerpt">{{ excerpt(d.content) }}</p>
          <div class="item__foot">
            <span class="item__intensity">
              <AppIcon name="wind" :size="14" />
              {{ softIntensity(d.intensity) }}
            </span>
            <div class="item__actions">
              <AppButton size="sm" kind="text" icon="eye" @click="open(d)">查看</AppButton>
              <AppButton size="sm" kind="text" icon="edit" @click="router.push(`/diary/${d.id}/edit`)">
                编辑
              </AppButton>
              <AppButton size="sm" kind="text" icon="trash" @click="askDelete(d)">删除</AppButton>
            </div>
          </div>
        </article>
      </div>
    </div>

    <AppModal v-model="deleteModal" title="删除这篇日记？" width="400">
      <p class="modal-text">
        删除后无法恢复。如果只是想清空心情，也可以先留着，过段时间再看或许不一样。
      </p>
      <template #footer>
        <AppButton kind="secondary" @click="deleteTarget = null">保留</AppButton>
        <AppButton kind="danger" :loading="deleting" @click="doDelete">确认删除</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { deleteDiary, listDiaries } from '../../api/diary'
import type { Diary } from '../../api/types'
import {
  EMOTIONS,
  emotionEmoji,
  emotionKind,
  formatDateTime,
  softIntensity,
} from '../../utils/format'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppEmpty from '../../components/ui/AppEmpty.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppModal from '../../components/ui/AppModal.vue'
import AppSkeleton from '../../components/ui/AppSkeleton.vue'
import AppTag from '../../components/ui/AppTag.vue'

const router = useRouter()

const diaries = ref<Diary[]>([])
const loading = ref(true)
const activeEmotion = ref('')
const deleteTarget = ref<Diary | null>(null)
const deleting = ref(false)

/** AppModal 需要 boolean 的 v-model，这里把「目标日记是否存在」映射为开关 */
const deleteModal = computed({
  get: () => deleteTarget.value !== null,
  set: (open: boolean) => {
    if (!open) deleteTarget.value = null
  },
})

const visible = computed(() =>
  activeEmotion.value
    ? diaries.value.filter((d) => (d.emotion ?? '').includes(activeEmotion.value))
    : diaries.value,
)

const dominantEmotion = computed(() => {
  const counter = new Map<string, number>()
  diaries.value.forEach((d) => {
    const key = (d.emotion || '').trim()
    if (key) counter.set(key, (counter.get(key) ?? 0) + 1)
  })
  let best = ''
  let max = 0
  counter.forEach((count, key) => {
    if (count > max) {
      max = count
      best = key
    }
  })
  return best
})

const thisMonthCount = computed(() => {
  const now = new Date()
  return diaries.value.filter((d) => {
    const t = new Date(String(d.createTime).replace(' ', 'T'))
    return (
      !Number.isNaN(t.getTime()) &&
      t.getFullYear() === now.getFullYear() &&
      t.getMonth() === now.getMonth()
    )
  }).length
})

function excerpt(content: string): string {
  const text = (content || '').replace(/\s+/g, ' ').trim()
  if (!text) return '（这篇还没有正文）'
  return text.length > 88 ? `${text.slice(0, 88)}…` : text
}

function open(d: Diary): void {
  router.push(`/diary/${d.id}`)
}

function askDelete(d: Diary): void {
  deleteTarget.value = d
}

async function doDelete(): Promise<void> {
  const target = deleteTarget.value
  if (!target) return
  deleting.value = true
  try {
    await deleteDiary(target.id)
    diaries.value = diaries.value.filter((d) => d.id !== target.id)
    deleteTarget.value = null
    toast.success('已删除')
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '删除失败，请稍后再试')
  } finally {
    deleting.value = false
  }
}

onMounted(async () => {
  try {
    diaries.value = await listDiaries()
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '日记加载失败')
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-4xl);
}
.page__head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--space-xl);
  flex-wrap: wrap;
}
.page__title {
  margin-top: var(--space-l);
  font-size: clamp(24px, 3.2vw, 34px);
}
.page__sub {
  margin-top: var(--space-s);
  font-size: var(--font-l);
  color: var(--text-2);
}

.stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-l);
  margin-top: var(--space-2xl);
}
.stat {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: var(--space-l) var(--space-xl);
  border-radius: var(--radius-lg);
  background: var(--bg-soft);
  border: 1px solid var(--line);
}
.stat__num {
  font-size: var(--font-stat);
  font-weight: 700;
  color: var(--primary);
  line-height: 1.2;
}
.stat__label {
  font-size: var(--font-xs);
  color: var(--text-3);
}

.filters {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-s);
  margin: var(--space-2xl) 0 var(--space-l);
}
.pill {
  padding: 7px 14px;
  border-radius: var(--radius-full);
  border: 1px solid var(--line-strong);
  background: var(--card);
  color: var(--text-2);
  font-size: var(--font-s);
  cursor: pointer;
  transition:
    border-color var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard);
}
.pill:hover {
  border-color: var(--primary-border);
  color: var(--primary);
}
.pill--active {
  background: var(--primary);
  border-color: var(--primary);
  color: var(--primary-contrast);
}

.list {
  display: flex;
  flex-direction: column;
  gap: var(--space-l);
}
.item {
  padding: var(--space-xl) var(--space-2xl);
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
  display: flex;
  flex-direction: column;
  gap: var(--space-m);
}
.item__top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
}
.item__date {
  font-size: var(--font-xs);
  color: var(--text-3);
}
.item__title {
  margin-top: var(--space-m);
  font-size: var(--font-xl);
  cursor: pointer;
  transition: color var(--motion-fast) var(--ease-standard);
}
.item__title:hover {
  color: var(--primary);
}
.item__excerpt {
  margin-top: var(--space-s);
  font-size: var(--font-m);
  line-height: 1.9;
  color: var(--text-2);
}
.item__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
  margin-top: var(--space-l);
  flex-wrap: wrap;
}
.item__intensity {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-xs);
  color: var(--text-3);
}
.item__actions {
  display: inline-flex;
  align-items: center;
  gap: var(--space-xs);
}

.modal-text {
  font-size: var(--font-m);
  line-height: 1.9;
  color: var(--text-2);
}

@media (max-width: 700px) {
  .stats {
    grid-template-columns: 1fr;
  }
}
</style>
