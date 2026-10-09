<template>
  <div class="page">
    <div class="container container--read">
      <RouterLink to="/diary" class="back">
        <AppIcon name="arrow-left" :size="16" />
        返回日记列表
      </RouterLink>

      <div v-if="loading" class="skeleton">
        <AppSkeleton height="18px" width="26%" />
        <AppSkeleton height="28px" width="66%" />
        <AppSkeleton height="14px" width="100%" />
        <AppSkeleton height="14px" width="92%" />
      </div>

      <AppEmpty
        v-else-if="!diary"
        icon="edit"
        title="这篇日记找不到了"
        description="它可能已经被删除，或者不属于当前账号"
      >
        <template #action>
          <AppButton kind="secondary" @click="router.replace('/diary')">返回日记列表</AppButton>
        </template>
      </AppEmpty>

      <article v-else class="diary">
        <header class="diary__head">
          <AppTag :kind="emotionKind(diary.emotion)" size="md">
            {{ emotionEmoji(diary.emotion) }} {{ diary.emotion }}
          </AppTag>
          <h1 class="diary__title">{{ diary.title || '（未命名）' }}</h1>
          <div class="diary__meta">
            <span><AppIcon name="clock" :size="14" /> {{ formatDateTime(diary.createTime) }}</span>
            <span class="diary__dot">·</span>
            <span><AppIcon name="wind" :size="14" /> {{ softIntensity(diary.intensity) }}</span>
          </div>
        </header>

        <div v-if="diary.event" class="diary__event">
          <AppIcon name="calendar" :size="15" />
          {{ diary.event }}
        </div>

        <div class="diary__body">
          <p v-for="(para, i) in paragraphs" :key="i" class="diary__para">{{ para }}</p>
        </div>

        <footer class="diary__foot">
          <AppButton kind="secondary" icon="edit" @click="router.push(`/diary/${diary.id}/edit`)">
            编辑
          </AppButton>
          <AppButton kind="ghost" icon="trash" @click="confirmDelete = true">删除</AppButton>
        </footer>
      </article>
    </div>

    <AppModal v-model="confirmDelete" title="删除这篇日记？" width="400">
      <p class="modal-text">删除后无法恢复，确定要删除吗？</p>
      <template #footer>
        <AppButton kind="secondary" @click="confirmDelete = false">保留</AppButton>
        <AppButton kind="danger" :loading="deleting" @click="doDelete">确认删除</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { deleteDiary, getDiary } from '../../api/diary'
import type { Diary } from '../../api/types'
import {
  emotionEmoji,
  emotionKind,
  formatDateTime,
  softIntensity,
  toParagraphs,
} from '../../utils/format'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppEmpty from '../../components/ui/AppEmpty.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppModal from '../../components/ui/AppModal.vue'
import AppSkeleton from '../../components/ui/AppSkeleton.vue'
import AppTag from '../../components/ui/AppTag.vue'

const route = useRoute()
const router = useRouter()

const diary = ref<Diary | null>(null)
const loading = ref(true)
const confirmDelete = ref(false)
const deleting = ref(false)

const paragraphs = computed(() => {
  if (!diary.value) return []
  const list = toParagraphs(diary.value.content)
  return list.length > 0 ? list : ['（这篇日记还没有正文）']
})

async function load(id: string): Promise<void> {
  loading.value = true
  diary.value = null
  try {
    diary.value = await getDiary(Number(id))
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '日记加载失败')
  } finally {
    loading.value = false
  }
}

async function doDelete(): Promise<void> {
  if (!diary.value) return
  deleting.value = true
  try {
    await deleteDiary(diary.value.id)
    toast.success('已删除')
    router.replace('/diary')
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '删除失败，请稍后再试')
  } finally {
    deleting.value = false
  }
}

onMounted(() => load(String(route.params.id)))
watch(
  () => route.params.id,
  (id) => {
    if (id) load(String(id))
  },
)
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-4xl);
}
.container--read {
  max-width: 720px;
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
.skeleton {
  display: flex;
  flex-direction: column;
  gap: var(--space-l);
  margin-top: var(--space-2xl);
}

.diary {
  margin-top: var(--space-xl);
}
.diary__head {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--space-m);
}
.diary__title {
  font-size: clamp(24px, 3.4vw, 34px);
  line-height: 1.4;
}
.diary__meta {
  display: flex;
  align-items: center;
  gap: var(--space-s);
  font-size: var(--font-s);
  color: var(--text-3);
}
.diary__meta span {
  display: inline-flex;
  align-items: center;
  gap: 5px;
}
.diary__dot {
  opacity: 0.6;
}
.diary__event {
  display: inline-flex;
  align-items: center;
  gap: var(--space-s);
  margin-top: var(--space-xl);
  padding: 8px 14px;
  border-radius: var(--radius-full);
  background: var(--bg-soft);
  border: 1px solid var(--line);
  font-size: var(--font-s);
  color: var(--text-2);
}
.diary__body {
  margin-top: var(--space-2xl);
  padding-top: var(--space-2xl);
  border-top: 1px solid var(--line);
}
.diary__para {
  font-size: var(--font-l);
  line-height: 2.1;
  color: var(--text);
  white-space: pre-wrap;
}
.diary__para + .diary__para {
  margin-top: var(--space-xl);
}
.diary__foot {
  display: flex;
  gap: var(--space-m);
  margin-top: var(--space-4xl);
  padding-top: var(--space-xl);
  border-top: 1px solid var(--line);
}
.modal-text {
  font-size: var(--font-m);
  line-height: 1.9;
  color: var(--text-2);
}
</style>
