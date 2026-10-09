<template>
  <div class="page">
    <div class="container">
      <header class="hero">
        <div class="hero__avatar">
          <img v-if="avatar" :src="avatar" :alt="displayName" />
          <span v-else class="hero__initial">{{ initial }}</span>
        </div>
        <div class="hero__info">
          <h1 class="hero__name">{{ displayName }}</h1>
          <p class="hero__sign">{{ signature || '还没有签名，写一句此刻想说的话吧' }}</p>
          <p class="hero__phone">
            <AppIcon name="phone" :size="14" />
            <span>{{ maskedPhone || '未绑定手机号' }}</span>
          </p>
        </div>
        <AppButton kind="secondary" icon="edit" @click="router.push('/me/profile')">编辑资料</AppButton>
      </header>

      <section class="entries">
        <RouterLink v-for="(e, i) in entries" :key="e.to" :to="e.to" class="entry" v-reveal="i * 70">
          <span class="entry__icon"><AppIcon :name="e.icon" :size="20" /></span>
          <span class="entry__text">
            <span class="entry__title">{{ e.title }}</span>
            <span class="entry__desc">{{ e.desc }}</span>
          </span>
          <AppIcon name="chevron-right" :size="16" class="entry__arrow" />
        </RouterLink>
      </section>

      <section class="section">
        <div class="section__bar">
          <h2 class="section__title">最近的心情</h2>
          <RouterLink to="/diary" class="section__more">
            全部日记 <AppIcon name="chevron-right" :size="14" />
          </RouterLink>
        </div>

        <div v-if="loading" class="mini">
          <div v-for="i in 3" :key="i" class="mini__item mini__item--skeleton">
            <AppSkeleton height="13px" width="40%" />
            <AppSkeleton height="15px" width="70%" />
          </div>
        </div>

        <div v-else-if="recentDiaries.length === 0" class="blank">
          <AppIcon name="edit" :size="20" />
          <span>还没有日记，写下第一篇吧</span>
          <AppButton size="sm" @click="router.push('/diary/new')">写一篇</AppButton>
        </div>

        <div v-else class="mini">
          <RouterLink v-for="d in recentDiaries" :key="d.id" :to="`/diary/${d.id}`" class="mini__item">
            <div class="mini__row">
              <AppTag :kind="emotionKind(d.emotion)" size="sm">{{ emotionEmoji(d.emotion) }} {{ d.emotion }}</AppTag>
              <span class="mini__time">{{ formatDateTime(d.createTime) }}</span>
            </div>
            <span class="mini__title">{{ d.title || '（未命名）' }}</span>
          </RouterLink>
        </div>
      </section>

      <section class="section">
        <div class="section__bar">
          <h2 class="section__title">最近的测评</h2>
          <RouterLink to="/me/records" class="section__more">
            全部记录 <AppIcon name="chevron-right" :size="14" />
          </RouterLink>
        </div>

        <div v-if="loading" class="mini">
          <div v-for="i in 2" :key="i" class="mini__item mini__item--skeleton">
            <AppSkeleton height="13px" width="40%" />
            <AppSkeleton height="15px" width="70%" />
          </div>
        </div>

        <div v-else-if="recentResults.length === 0" class="blank">
          <AppIcon name="clipboard" :size="20" />
          <span>还没有测评记录</span>
          <AppButton size="sm" @click="router.push('/assessment')">去自查</AppButton>
        </div>

        <div v-else class="mini">
          <RouterLink
            v-for="r in recentResults"
            :key="r.id"
            :to="`/assessment/result/${r.id}`"
            class="mini__item"
          >
            <div class="mini__row">
              <AppTag :kind="softLevelKind(r.level)" size="sm">{{ softLevel(r.level) }}</AppTag>
              <span class="mini__time">{{ formatDateTime(r.createTime) }}</span>
            </div>
            <div class="mini__result">
              <span class="mini__title">{{ r.assessmentTitle }}</span>
              <span class="mini__score">{{ r.score }}<i>/{{ r.maxScore }}</i></span>
            </div>
          </RouterLink>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { fetchUserInfo } from '../../api/user'
import { listDiaries } from '../../api/diary'
import { fetchResults } from '../../api/assessment'
import type { AssessmentResult, Diary, UserVO } from '../../api/types'
import { useAuthStore } from '../../stores/auth'
import { emotionEmoji, emotionKind, formatDateTime, softLevel, softLevelKind } from '../../utils/format'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppSkeleton from '../../components/ui/AppSkeleton.vue'
import AppTag from '../../components/ui/AppTag.vue'

const router = useRouter()
const auth = useAuthStore()

const profile = ref<UserVO | null>(null)
const diaries = ref<Diary[]>([])
const results = ref<AssessmentResult[]>([])
const loading = ref(true)

const displayName = computed(() => profile.value?.nickname || auth.displayName)
const avatar = computed(() => profile.value?.avatar || auth.avatar)
const initial = computed(() => displayName.value.slice(0, 1) || '轻')
const signature = computed(() => profile.value?.signature || '')
const maskedPhone = computed(() => {
  const p = profile.value?.phone || auth.user?.phone || ''
  return p.length === 11 ? `${p.slice(0, 3)}****${p.slice(7)}` : p
})

const entries = [
  { to: '/me/profile', icon: 'user', title: '个人资料', desc: '昵称、头像与签名' },
  { to: '/me/records', icon: 'book', title: '我的记录', desc: '情绪日记与测评历史' },
  { to: '/settings', icon: 'settings', title: '设置', desc: '主题外观与账号' },
  { to: '/feedback', icon: 'message', title: '意见反馈', desc: '告诉我们你的想法' },
]

const recentDiaries = computed(() => diaries.value.slice(0, 3))
const recentResults = computed(() => results.value.slice(0, 3))

onMounted(async () => {
  const [me, d, r] = await Promise.allSettled([fetchUserInfo(), listDiaries(), fetchResults()])
  if (me.status === 'fulfilled') {
    profile.value = me.value
  } else {
    const err = me.reason
    toast.error(err instanceof Error && err.message ? err.message : '资料加载失败')
  }
  if (d.status === 'fulfilled') diaries.value = d.value ?? []
  if (r.status === 'fulfilled') results.value = r.value ?? []
  loading.value = false
})
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-4xl);
}

.hero {
  display: flex;
  align-items: center;
  gap: var(--space-xl);
  padding: var(--space-2xl);
  border-radius: var(--radius-xl);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm), inset 0 1px 0 var(--glass-sheen);
  flex-wrap: wrap;
}
.hero__avatar {
  display: grid;
  place-items: center;
  width: 76px;
  height: 76px;
  border-radius: var(--radius-full);
  overflow: hidden;
  background: var(--card);
  border: 2px solid var(--primary-border);
  flex: none;
}
.hero__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.hero__initial {
  font-size: 30px;
  font-weight: 700;
  color: var(--primary);
}
.hero__info {
  flex: 1;
  min-width: 200px;
}
.hero__name {
  font-size: var(--font-3xl);
}
.hero__sign {
  margin-top: 4px;
  font-size: var(--font-m);
  color: var(--text-2);
}
.hero__phone {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin-top: var(--space-s);
  font-size: var(--font-s);
  color: var(--text-3);
}

.entries {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--space-l);
  margin-top: var(--space-2xl);
}
.entry {
  display: flex;
  align-items: center;
  gap: var(--space-m);
  padding: var(--space-l);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
  transition:
    transform var(--motion-normal) var(--ease-emphasized),
    border-color var(--motion-normal) var(--ease-standard),
    box-shadow var(--motion-normal) var(--ease-standard);
}
.entry:hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.entry__icon {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  border-radius: var(--radius-md);
  background: var(--primary-weak);
  color: var(--primary);
  flex: none;
}
.entry__text {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.entry__title {
  font-size: var(--font-m);
  font-weight: 600;
}
.entry__desc {
  font-size: var(--font-xs);
  color: var(--text-3);
}
.entry__arrow {
  margin-left: auto;
  color: var(--text-3);
  flex: none;
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

.mini {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-l);
  margin-top: var(--space-l);
}
.mini__item {
  display: flex;
  flex-direction: column;
  gap: var(--space-s);
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
.mini__item:not(.mini__item--skeleton):hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.mini__item--skeleton {
  gap: var(--space-m);
  box-shadow: none;
}
.mini__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
}
.mini__result {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
}
.mini__title {
  font-size: var(--font-m);
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.mini__time {
  font-size: var(--font-xs);
  color: var(--text-3);
  white-space: nowrap;
}
.mini__score {
  font-size: var(--font-xl);
  font-weight: 700;
  color: var(--primary);
  line-height: 1;
  white-space: nowrap;
}
.mini__score i {
  font-size: var(--font-2xs);
  font-style: normal;
  font-weight: 500;
  color: var(--text-3);
}

.blank {
  display: flex;
  align-items: center;
  gap: var(--space-m);
  margin-top: var(--space-l);
  padding: var(--space-xl);
  border-radius: var(--radius-lg);
  background: var(--bg-soft);
  border: 1px solid var(--line);
  color: var(--text-3);
  font-size: var(--font-m);
}
.blank :first-child {
  color: var(--primary);
}
.blank > span {
  flex: 1;
}

@media (max-width: 900px) {
  .entries {
    grid-template-columns: repeat(2, 1fr);
  }
  .mini {
    grid-template-columns: repeat(2, 1fr);
  }
}
@media (max-width: 640px) {
  .entries {
    grid-template-columns: 1fr;
  }
  .mini {
    grid-template-columns: 1fr;
  }
  .hero {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
