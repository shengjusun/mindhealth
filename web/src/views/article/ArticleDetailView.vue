<template>
  <div class="page">
    <div class="container container--narrow">
      <RouterLink to="/articles" class="back">
        <AppIcon name="arrow-left" :size="16" />
        返回文章列表
      </RouterLink>

      <div v-if="loading" class="skeleton">
        <AppSkeleton height="26px" width="70%" />
        <AppSkeleton height="14px" width="40%" />
        <AppSkeleton height="13px" width="100%" />
        <AppSkeleton height="13px" width="96%" />
        <AppSkeleton height="13px" width="88%" />
      </div>

      <AppEmpty
        v-else-if="!article"
        icon="book-open"
        title="这篇文章走丢了"
        description="它可能已经被编辑部下架，去看看其它文章吧"
      >
        <template #action>
          <AppButton kind="secondary" @click="router.replace('/articles')">返回文章列表</AppButton>
        </template>
      </AppEmpty>

      <article v-else class="article">
        <header class="article__head">
          <AppTag v-if="article.category" kind="primary" size="sm">{{ article.category }}</AppTag>
          <h1 class="article__title">{{ article.title }}</h1>
          <div class="article__meta">
            <span class="article__author">
              <AppIcon name="user" :size="14" />
              {{ article.author }}
            </span>
            <span class="article__dot">·</span>
            <span class="article__time">
              <AppIcon name="clock" :size="14" />
              {{ formatDateTime(article.createTime) }}
            </span>
          </div>
        </header>

        <img v-if="article.cover" class="article__cover" :src="article.cover" :alt="article.title" />

        <p v-if="article.summary" class="article__summary">{{ article.summary }}</p>

        <div class="article__body">
          <p v-for="(para, i) in paragraphs" :key="i" class="article__para">{{ para }}</p>
        </div>

        <footer class="article__foot">
          <div class="article__tip">
            <AppIcon name="heart" :size="16" />
            如果这篇文章让你想起了什么，不妨去日记里写下来。
          </div>
          <div class="article__actions">
            <AppButton size="sm" kind="secondary" icon="edit" @click="goDiary">写进日记</AppButton>
            <AppButton size="sm" kind="ghost" icon="arrow-right" @click="router.push('/ai')">和树洞说说</AppButton>
          </div>
        </footer>
      </article>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { getArticle } from '../../api/article'
import type { ArticleVO } from '../../api/types'
import { formatDateTime, toParagraphs } from '../../utils/format'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppEmpty from '../../components/ui/AppEmpty.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppSkeleton from '../../components/ui/AppSkeleton.vue'
import AppTag from '../../components/ui/AppTag.vue'

const route = useRoute()
const router = useRouter()

const article = ref<ArticleVO | null>(null)
const loading = ref(true)

const paragraphs = computed(() => {
  if (!article.value) return []
  const list = toParagraphs(article.value.content)
  return list.length > 0 ? list : ['（这篇还没有正文内容）']
})

async function load(id: string): Promise<void> {
  loading.value = true
  article.value = null
  try {
    article.value = await getArticle(Number(id))
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '文章加载失败')
  } finally {
    loading.value = false
  }
}

function goDiary(): void {
  router.push('/diary/new')
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
.container--narrow {
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

.skeleton {
  display: flex;
  flex-direction: column;
  gap: var(--space-l);
  margin-top: var(--space-2xl);
}

.article {
  margin-top: var(--space-xl);
}
.article__head {
  display: flex;
  flex-direction: column;
  gap: var(--space-m);
  align-items: flex-start;
}
.article__title {
  font-size: clamp(26px, 3.6vw, 36px);
  line-height: 1.35;
}
.article__meta {
  display: flex;
  align-items: center;
  gap: var(--space-s);
  font-size: var(--font-s);
  color: var(--text-3);
}
.article__author,
.article__time {
  display: inline-flex;
  align-items: center;
  gap: 5px;
}
.article__dot {
  opacity: 0.6;
}
.article__cover {
  display: block;
  width: 100%;
  margin-top: var(--space-2xl);
  border-radius: var(--radius-lg);
  border: 1px solid var(--line);
}
.article__summary {
  margin-top: var(--space-2xl);
  padding: var(--space-l) var(--space-xl);
  border: 1px solid var(--line);
  border-radius: var(--radius-md);
  background: var(--bg-soft);
  font-size: var(--font-l);
  line-height: 1.95;
  color: var(--text-2);
}
.article__body {
  margin-top: var(--space-2xl);
}
.article__para {
  font-size: var(--font-l);
  line-height: 2.1;
  color: var(--text);
  white-space: pre-wrap;
}
.article__para + .article__para {
  margin-top: var(--space-xl);
}
.article__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-l);
  margin-top: var(--space-4xl);
  padding: var(--space-l) var(--space-xl);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm), inset 0 1px 0 var(--glass-sheen);
  flex-wrap: wrap;
}
.article__tip {
  display: inline-flex;
  align-items: center;
  gap: var(--space-s);
  font-size: var(--font-m);
  color: var(--text-2);
}
.article__actions {
  display: inline-flex;
  gap: var(--space-s);
  flex-wrap: wrap;
}
</style>
