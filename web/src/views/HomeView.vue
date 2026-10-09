<template>
  <div class="home">
    <!-- Hero -->
    <section class="hero">
      <div class="container hero__inner">
        <div class="hero__copy">
          <AppTag kind="primary" icon="sparkles" size="md">温柔的情绪陪伴</AppTag>
          <h1 class="hero__title">
            把心情，<br />
            安放在<span class="hero__accent">这里</span>
          </h1>
          <p class="hero__desc">
            记录情绪、读懂自己、和树洞说说话。<br />
            轻心不评判、不催促，只陪你慢慢看见内心的天气。
          </p>
          <div class="hero__actions">
            <template v-if="auth.isLoggedIn">
              <AppButton size="lg" icon="edit" @click="router.push('/diary/new')">写一篇日记</AppButton>
              <AppButton size="lg" kind="secondary" icon="message" @click="router.push('/ai')">找树洞聊聊</AppButton>
            </template>
            <template v-else>
              <AppButton size="lg" icon="arrow-right" @click="router.push('/register')">免费开始</AppButton>
              <AppButton size="lg" kind="secondary" icon="book-open" @click="router.push('/articles')">先看看文章</AppButton>
            </template>
          </div>
          <p class="hero__hint">
            <AppIcon name="shield" :size="15" />
            你的记录只属于你自己
          </p>
        </div>

        <div class="hero__visual">
          <div class="glass">
            <div class="glass__head">
              <span class="glass__label">今天的心情</span>
              <AppTag kind="primary" size="sm">已记录</AppTag>
            </div>
            <div class="glass__emotions">
              <span v-for="e in EMOTIONS" :key="e" class="emo" :class="`emo--${emotionKind(e)}`">
                <span class="emo__dot"></span>
                {{ e }}
              </span>
            </div>
            <div class="glass__note">
              <span class="glass__quote">{{ QUOTE }}</span>
            </div>
          </div>
          <span class="hero__blob hero__blob--a"></span>
          <span class="hero__blob hero__blob--b"></span>
        </div>
      </div>
    </section>

    <!-- 数据条 -->
    <section class="stats">
      <div class="container">
        <div class="stats__card">
          <div v-for="s in stats" :key="s.label" class="stat">
            <span class="stat__value" :class="{ 'stat__value--dim': s.dim }">{{ s.value }}</span>
            <span class="stat__label">{{ s.label }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- 功能 -->
    <section class="block container">
      <header class="block__head">
        <h2 class="block__title">四件小事，慢慢照看自己</h2>
        <p class="block__sub">不需要一次做完，挑一件此刻愿意做的就好。</p>
      </header>

      <div class="features">
        <RouterLink v-for="f in FEATURES" :key="f.to" :to="f.to" class="feature">
          <span class="feature__icon"><AppIcon :name="f.icon" :size="22" /></span>
          <h3 class="feature__title">{{ f.title }}</h3>
          <p class="feature__desc">{{ f.desc }}</p>
          <span class="feature__more">
            去看看
            <AppIcon name="arrow-right" :size="15" />
          </span>
        </RouterLink>
      </div>
    </section>

    <!-- 三步 -->
    <section class="block steps-block">
      <div class="container">
        <header class="block__head">
          <h2 class="block__title">三步，认识此刻的自己</h2>
          <p class="block__sub">从记录到理解，是一段温柔的自我对话。</p>
        </header>
        <ol class="steps">
          <li v-for="(s, i) in STEPS" :key="s.title" class="step">
            <span class="step__index">{{ i + 1 }}</span>
            <div class="step__body">
              <h3 class="step__title">{{ s.title }}</h3>
              <p class="step__desc">{{ s.desc }}</p>
            </div>
          </li>
        </ol>
      </div>
    </section>

    <!-- 文章 -->
    <section class="block container">
      <header class="block__head block__head--row">
        <div>
          <h2 class="block__title">读一点，心里松一点</h2>
          <p class="block__sub">来自轻心编辑部的精选内容。</p>
        </div>
        <RouterLink to="/articles" class="block__more">
          全部文章
          <AppIcon name="arrow-right" :size="15" />
        </RouterLink>
      </header>

      <div v-if="articlesLoading" class="articles">
        <div v-for="i in 3" :key="i" class="article article--skeleton">
          <AppSkeleton height="14px" width="46%" />
          <AppSkeleton height="12px" width="100%" />
          <AppSkeleton height="12px" width="78%" />
        </div>
      </div>

      <div v-else-if="articles.length === 0" class="articles-empty">
        <AppEmpty title="暂无文章" description="编辑部正在认真准备，稍后再来看看" icon="book-open" />
      </div>

      <div v-else class="articles">
        <RouterLink
          v-for="a in articles"
          :key="a.id"
          :to="`/articles/${a.id}`"
          class="article"
        >
          <AppTag v-if="a.category" kind="accent" size="sm">{{ a.category }}</AppTag>
          <h3 class="article__title">{{ a.title }}</h3>
          <p class="article__summary">{{ a.summary || '（这篇还没有摘要）' }}</p>
          <span class="article__foot">
            <span class="article__author">{{ a.author }}</span>
            <span class="article__dot">·</span>
            <span>{{ formatDate(a.createTime) }}</span>
          </span>
        </RouterLink>
      </div>
    </section>

    <!-- CTA -->
    <section class="cta container">
      <div class="cta__card">
        <div class="cta__text">
          <h2 class="cta__title">今天的心情，值得被记下</h2>
          <p class="cta__desc">哪怕只是一句话。轻心会替你把它们好好收着。</p>
        </div>
        <div class="cta__actions">
          <AppButton v-if="!auth.isLoggedIn" size="lg" @click="router.push('/register')">免费开始</AppButton>
          <AppButton v-else size="lg" icon="edit" @click="router.push('/diary/new')">现在就写</AppButton>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { listArticles } from '../api/article'
import { fetchManifest, fetchResults } from '../api/assessment'
import { listDiaries } from '../api/diary'
import type { ArticleVO } from '../api/types'
import { useAuthStore } from '../stores/auth'
import { EMOTIONS, emotionKind, formatDate } from '../utils/format'
import AppButton from '../components/ui/AppButton.vue'
import AppEmpty from '../components/ui/AppEmpty.vue'
import AppIcon from '../components/ui/AppIcon.vue'
import AppSkeleton from '../components/ui/AppSkeleton.vue'
import AppTag from '../components/ui/AppTag.vue'

const auth = useAuthStore()
const router = useRouter()

const QUOTE = '心情没有好坏，它只是在告诉你，此刻发生了什么。'

const FEATURES = [
  {
    to: '/diary',
    icon: 'edit',
    title: '情绪日记',
    desc: '选一个情绪、写几句话，给今天的心情留个位置。',
  },
  {
    to: '/assessment',
    icon: 'clipboard',
    title: '状态自查',
    desc: '几分钟的温和问卷，帮你看清当下的状态起伏。',
  },
  {
    to: '/ai',
    icon: 'message',
    title: '树洞陪伴',
    desc: '想说什么都可以，树洞会安静地听，认真地回。',
  },
  {
    to: '/articles',
    icon: 'book-open',
    title: '文章',
    desc: '睡不着或心里乱时，读一点轻而稳的文字。',
  },
]

const STEPS = [
  { title: '记录', desc: '在日记里标出情绪与强度，让模糊的感受有名字。' },
  { title: '了解', desc: '用自查量表看看当下的状态，得到一份温和的解读。' },
  { title: '陪伴', desc: '把说不出口的话交给树洞，也在文章里找到共鸣。' },
]

const articles = ref<ArticleVO[]>([])
const articlesLoading = ref(true)
const scaleCount = ref(0)
const diaryCount = ref(0)
const resultCount = ref(0)

const stats = computed(() => {
  const isDim = (value: string) => value.startsWith('0') || value === '—'
  const base = [
    { label: '状态自查量表', value: scaleCount.value > 0 ? `${scaleCount.value} 份` : '—' },
    { label: '精选文章', value: articles.value.length > 0 ? `${articles.value.length} 篇` : '—' },
  ]
  if (auth.isLoggedIn) {
    base.push(
      { label: '我写过的日记', value: `${diaryCount.value} 篇` },
      { label: '我做过的自查', value: `${resultCount.value} 次` },
    )
  } else {
    base.push(
      { label: '情绪可记录种类', value: `${EMOTIONS.length} 种` },
      { label: '树洞陪伴', value: '随时在线' },
    )
  }
  return base.map((s) => ({ ...s, dim: isDim(s.value) }))
})

onMounted(async () => {
  const tasks: Promise<unknown>[] = [
    listArticles().then((list) => {
      articles.value = list.slice(0, 3)
    }),
    fetchManifest().then((m) => {
      scaleCount.value = m.scales.length
    }),
  ]
  if (auth.isLoggedIn) {
    tasks.push(listDiaries().then((list) => (diaryCount.value = list.length)))
    tasks.push(fetchResults().then((list) => (resultCount.value = list.length)))
  }
  await Promise.allSettled(tasks)
  articlesLoading.value = false
})
</script>

<style scoped>
/* ---------------------------------------------------------------- Hero
 * 白底之上仅叠一层极淡的氛围光；内容卡片一律为「纯白 + 1px 描边 + 扩散柔阴影」，
 * 靠阴影的近实远虚在白底上浮起，而不是靠异色底块。 */
.hero {
  position: relative;
  overflow: hidden;
  background:
    radial-gradient(50% 66% at 8% -18%, var(--primary-weak), transparent 58%),
    radial-gradient(40% 56% at 97% -12%, var(--accent-weak), transparent 58%);
}
/* 区块收口：两端渐隐的 1px 细线，替代生硬的整条分隔线 */
.hero::after {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 1px;
  background: linear-gradient(90deg, transparent, var(--line), transparent);
}
.hero__inner {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: 1.08fr 0.92fr;
  align-items: center;
  gap: var(--space-4xl);
  padding: clamp(44px, 6.2vw, 84px) 0 clamp(34px, 4.6vw, 56px);
}
.hero__title {
  margin-top: var(--space-l);
  font-size: clamp(34px, 5vw, 56px);
  line-height: 1.2;
  letter-spacing: -0.01em;
}
.hero__accent {
  position: relative;
  color: var(--primary);
}
.hero__accent::after {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  bottom: 4px;
  height: 10px;
  border-radius: var(--radius-full);
  background: var(--primary-weak2);
  z-index: -1;
}
.hero__desc {
  margin-top: var(--space-xl);
  max-width: 520px;
  font-size: var(--font-xl);
  line-height: 2;
  color: var(--text-2);
}
.hero__actions {
  display: flex;
  gap: var(--space-m);
  margin-top: var(--space-3xl);
  flex-wrap: wrap;
}
.hero__hint {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin-top: var(--space-xl);
  font-size: var(--font-s);
  color: var(--text-3);
}

.hero__visual {
  position: relative;
  display: flex;
  justify-content: center;
}
/* 纯白卡片：白底上靠描边勾形、靠多层柔阴影浮起 */
.glass {
  position: relative;
  z-index: 2;
  width: 100%;
  max-width: 384px;
  padding: var(--space-2xl);
  border-radius: var(--radius-2xl);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-lg), inset 0 1px 0 var(--glass-sheen);
  transition:
    transform var(--motion-slow) var(--ease-emphasized),
    box-shadow var(--motion-slow) var(--ease-standard);
}
.glass:hover {
  transform: translateY(-3px);
  box-shadow: var(--shadow-glow), var(--shadow-lg), inset 0 1px 0 var(--glass-sheen);
}
.glass__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--space-l);
}
.glass__label {
  font-size: var(--font-l);
  font-weight: 700;
  color: var(--text);
}
.glass__emotions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-s);
}
.emo {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 7px 13px;
  border-radius: var(--radius-full);
  font-size: var(--font-s);
  font-weight: 600;
  background: var(--card-soft);
  color: var(--text-2);
  border: 1px solid var(--line);
  transition:
    transform var(--motion-fast) var(--ease-standard),
    box-shadow var(--motion-fast) var(--ease-standard);
}
.emo:hover {
  transform: translateY(-1px);
  box-shadow: var(--shadow-sm);
}
.emo__dot {
  width: 8px;
  height: 8px;
  border-radius: var(--radius-full);
  background: currentColor;
  box-shadow: 0 0 0 3px color-mix(in srgb, currentColor 20%, transparent);
}
.emo--primary {
  background: var(--primary-weak);
  color: var(--primary);
  border-color: var(--primary-border);
}
.emo--success {
  background: color-mix(in srgb, var(--success) 12%, transparent);
  color: var(--success);
}
.emo--warning {
  background: color-mix(in srgb, var(--warning) 14%, transparent);
  color: var(--warning);
}
.emo--danger {
  background: color-mix(in srgb, var(--danger) 12%, transparent);
  color: var(--danger);
}
.glass__note {
  margin-top: var(--space-xl);
  padding: var(--space-l) var(--space-l) var(--space-l) var(--space-xl);
  border-radius: var(--radius-md);
  background: var(--primary-weak);
  border-left: 3px solid var(--primary-border);
}
.glass__quote {
  font-size: var(--font-s);
  line-height: 1.9;
  color: var(--text-2);
}

/* 卡片背后的柔光斑：白底上的光感来源，透过模糊铺开、不形成色块 */
.hero__blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(60px);
  opacity: 0.7;
  z-index: 1;
}
.hero__blob--a {
  width: 250px;
  height: 250px;
  top: -80px;
  right: 1%;
  background: var(--primary-weak2);
}
.hero__blob--b {
  width: 200px;
  height: 200px;
  bottom: -64px;
  left: -4%;
  background: var(--accent-weak);
}

/* ---------------------------------------------------------------- 数据条 */
.stats {
  padding-top: var(--space-4xl);
}
.stats__card {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  padding: var(--space-2xl) var(--space-l);
  border-radius: var(--radius-xl);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-md), inset 0 1px 0 var(--glass-sheen);
}
.stat {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  text-align: center;
}
.stat + .stat::before {
  content: '';
  position: absolute;
  left: 0;
  top: 12%;
  height: 76%;
  width: 1px;
  background: var(--line);
}
.stat__value {
  font-size: var(--font-stat);
  font-weight: 800;
  letter-spacing: -0.01em;
  background: linear-gradient(180deg, var(--primary), color-mix(in srgb, var(--primary) 82%, #000));
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  color: transparent;
}
.stat__value--dim {
  background: none;
  -webkit-text-fill-color: var(--text-3);
  color: var(--text-3);
}
.stat__label {
  font-size: var(--font-s);
  color: var(--text-3);
}

/* ---------------------------------------------------------------- 通用区块 */
.block {
  padding: var(--space-4xl) 0 0;
}
.block__head {
  max-width: 620px;
  margin-bottom: var(--space-2xl);
}
.block__head--row {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--space-xl);
  max-width: none;
}
.block__title {
  font-size: clamp(22px, 2.6vw, 30px);
}
.block__sub {
  margin-top: var(--space-s);
  font-size: var(--font-l);
  color: var(--text-3);
}
.block__more {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-m);
  font-weight: 600;
  color: var(--primary);
  white-space: nowrap;
  transition: gap var(--motion-fast) var(--ease-standard);
}
.block__more:hover {
  gap: 10px;
}

/* ---------------------------------------------------------------- 功能四宫格 */
.features {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--space-l);
}
.feature {
  display: flex;
  flex-direction: column;
  gap: var(--space-m);
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
.feature:hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.feature__icon {
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  border-radius: var(--radius-md);
  background: linear-gradient(160deg, var(--primary-weak2), var(--primary-weak));
  color: var(--primary);
  box-shadow: inset 0 1px 0 var(--glass-sheen);
}
.feature__title {
  font-size: var(--font-xl);
}
.feature__desc {
  flex: 1;
  font-size: var(--font-m);
  line-height: 1.85;
  color: var(--text-2);
}
.feature__more {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-s);
  font-weight: 600;
  color: var(--primary);
}

/* ---------------------------------------------------------------- 三步 */
.steps-block {
  padding-top: var(--space-4xl);
}
.steps {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-l);
  list-style: none;
  padding: 0;
  margin: 0;
}
.step {
  position: relative;
  display: flex;
  gap: var(--space-l);
  padding: var(--space-2xl);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
}
.step__index {
  flex: none;
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-full);
  background: var(--primary);
  color: var(--primary-contrast);
  font-weight: 700;
  box-shadow: var(--shadow-glow);
}
.step__title {
  font-size: var(--font-xl);
}
.step__desc {
  margin-top: 6px;
  font-size: var(--font-m);
  line-height: 1.85;
  color: var(--text-2);
}

/* ---------------------------------------------------------------- 文章 */
.articles {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-l);
}
.article {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--space-m);
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
.article:not(.article--skeleton):hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.article--skeleton {
  gap: var(--space-l);
}
.article__title {
  font-size: var(--font-xl);
  line-height: 1.5;
}
.article__summary {
  flex: 1;
  font-size: var(--font-m);
  line-height: 1.85;
  color: var(--text-2);
  display: -webkit-box;
  -webkit-line-clamp: 3;
  line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.article__foot {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-xs);
  color: var(--text-3);
}
.article__dot {
  opacity: 0.6;
}
.articles-empty {
  padding: var(--space-3xl) 0;
}

/* ---------------------------------------------------------------- CTA */
.cta {
  padding-top: var(--space-4xl);
}
.cta__card {
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2xl);
  padding: clamp(28px, 4vw, 48px);
  border-radius: var(--radius-xl);
  background:
    radial-gradient(80% 120% at 88% 12%, var(--accent-weak), transparent 58%),
    linear-gradient(135deg, var(--primary-weak2), var(--primary-weak));
  border: 1px solid var(--primary-border);
  box-shadow: var(--shadow-md);
  flex-wrap: wrap;
}
.cta__title {
  font-size: clamp(22px, 2.6vw, 28px);
}
.cta__desc {
  margin-top: var(--space-s);
  font-size: var(--font-l);
  color: var(--text-2);
}

/* ---------------------------------------------------------------- 响应式 */
@media (max-width: 1000px) {
  .features {
    grid-template-columns: repeat(2, 1fr);
  }
  .stats__card {
    grid-template-columns: repeat(2, 1fr);
    gap: var(--space-xl) 0;
    padding: var(--space-2xl);
  }
  .stat:nth-child(odd)::before {
    display: none;
  }
}
@media (max-width: 860px) {
  .hero__inner {
    grid-template-columns: 1fr;
    text-align: left;
  }
  .hero__visual {
    order: -1;
  }
  .steps,
  .articles {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 560px) {
  .features {
    grid-template-columns: 1fr;
  }
  .block__head--row {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
