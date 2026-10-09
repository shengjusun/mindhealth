<template>
  <div class="page">
    <div class="container">
      <header class="page__head">
        <AppTag kind="primary" icon="book-open" size="md">文章</AppTag>
        <h1 class="page__title">读一点，心里松一点</h1>
        <p class="page__sub">关于情绪、关系与自我照顾的轻量文字，随时可以放下，也随时可以再回来。</p>
      </header>

      <div class="toolbar">
        <div class="cats">
          <button
            v-for="c in categoryOptions"
            :key="c.value"
            type="button"
            class="cat"
            :class="{ 'cat--active': activeCategory === c.value }"
            @click="selectCategory(c.value)"
          >
            {{ c.label }}
            <span v-if="c.count !== undefined" class="cat__count">{{ c.count }}</span>
          </button>
        </div>
        <AppInput
          v-model="keyword"
          class="toolbar__search"
          placeholder="搜索标题或摘要"
          icon="search"
          type="text"
        />
      </div>

      <div v-if="loading" class="grid">
        <div v-for="i in 6" :key="i" class="card card--skeleton">
          <AppSkeleton height="14px" width="40%" />
          <AppSkeleton height="18px" width="86%" />
          <AppSkeleton height="12px" width="100%" />
          <AppSkeleton height="12px" width="72%" />
        </div>
      </div>

      <AppEmpty
        v-else-if="visibleArticles.length === 0"
        icon="book-open"
        title="没有找到相关文章"
        :description="keyword ? '换个关键词试试吧' : '编辑部正在认真准备，稍后再来看看'"
      />

      <div v-else class="grid">
        <RouterLink
          v-for="(a, i) in visibleArticles"
          :key="a.id"
          :to="`/articles/${a.id}`"
          class="card"
          v-reveal="i * 70"
        >
          <span v-if="a.category" class="card__cat">{{ a.category }}</span>
          <h2 class="card__title">{{ a.title }}</h2>
          <p class="card__summary">{{ a.summary || '（这篇还没有摘要）' }}</p>
          <span class="card__foot">
            <AppIcon name="user" :size="14" />
            {{ a.author }}
            <span class="card__dot">·</span>
            {{ formatDate(a.createTime) }}
          </span>
        </RouterLink>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { listArticles } from '../../api/article'
import type { ArticleVO } from '../../api/types'
import { formatDate } from '../../utils/format'
import { toast } from '../../utils/toast'
import AppEmpty from '../../components/ui/AppEmpty.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppInput from '../../components/ui/AppInput.vue'
import AppSkeleton from '../../components/ui/AppSkeleton.vue'
import AppTag from '../../components/ui/AppTag.vue'

const articles = ref<ArticleVO[]>([])
const loading = ref(true)
const activeCategory = ref('')
const keyword = ref('')

const categoryOptions = computed(() => {
  const counter = new Map<string, number>()
  articles.value.forEach((a) => {
    const key = (a.category || '').trim()
    if (!key) return
    counter.set(key, (counter.get(key) ?? 0) + 1)
  })
  return [
    { value: '', label: '全部', count: articles.value.length },
    ...Array.from(counter.entries()).map(([value, count]) => ({ value, label: value, count })),
  ]
})

const visibleArticles = computed(() => {
  const kw = keyword.value.trim().toLowerCase()
  return articles.value.filter((a) => {
    if (activeCategory.value && (a.category || '').trim() !== activeCategory.value) return false
    if (!kw) return true
    return (
      a.title.toLowerCase().includes(kw) ||
      (a.summary || '').toLowerCase().includes(kw)
    )
  })
})

function selectCategory(value: string): void {
  activeCategory.value = value
}

onMounted(async () => {
  try {
    articles.value = await listArticles()
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '文章加载失败，请稍后再试')
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.page {
  padding: var(--space-4xl) 0 var(--space-4xl);
}
.page__head {
  max-width: 660px;
}
.page__title {
  margin-top: var(--space-l);
  font-size: clamp(26px, 3.6vw, 38px);
}
.page__sub {
  margin-top: var(--space-m);
  font-size: var(--font-l);
  line-height: 1.95;
  color: var(--text-2);
}

.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-xl);
  margin: var(--space-3xl) 0 var(--space-2xl);
  flex-wrap: wrap;
}
.cats {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-s);
}
.cat {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border-radius: var(--radius-full);
  border: 1px solid var(--line-strong);
  background: var(--card);
  color: var(--text-2);
  font-size: var(--font-m);
  font-weight: 600;
  cursor: pointer;
  transition:
    background-color var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard),
    border-color var(--motion-fast) var(--ease-standard);
}
.cat:hover {
  border-color: var(--primary-border);
  color: var(--primary);
}
.cat--active {
  background: var(--primary);
  border-color: var(--primary);
  color: var(--primary-contrast);
}
.cat__count {
  font-size: var(--font-xs);
  opacity: 0.75;
}
.toolbar__search {
  width: 260px;
  max-width: 100%;
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: var(--space-l);
}
.card {
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
.card:not(.card--skeleton):hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.card--skeleton {
  gap: var(--space-l);
}
.card__cat {
  padding: 4px 10px;
  border-radius: var(--radius-full);
  background: var(--accent-weak);
  color: var(--accent);
  font-size: var(--font-xs);
  font-weight: 700;
}
.card__title {
  font-size: var(--font-xl);
  line-height: 1.5;
}
.card__summary {
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
.card__foot {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-xs);
  color: var(--text-3);
}
.card__dot {
  opacity: 0.6;
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
  .toolbar__search {
    width: 100%;
  }
}
</style>
