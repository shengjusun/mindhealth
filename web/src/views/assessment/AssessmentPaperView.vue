<template>
  <div class="page">
    <div class="container container--paper">
      <RouterLink to="/assessment" class="back">
        <AppIcon name="arrow-left" :size="16" />
        返回自查列表
      </RouterLink>

      <div v-if="loading" class="loading">
        <AppSpinner />
        <span>正在准备题目…</span>
      </div>

      <AppEmpty
        v-else-if="!paper || paper.questions.length === 0"
        icon="clipboard"
        title="这份量表暂时打不开"
        description="可能正在维护，先去试试其它量表吧"
      >
        <template #action>
          <AppButton kind="secondary" @click="router.replace('/assessment')">返回自查列表</AppButton>
        </template>
      </AppEmpty>

      <template v-else>
        <header class="head">
          <h1 class="head__title">{{ paper.name }}</h1>
          <p v-if="paper.description" class="head__sub">{{ paper.description }}</p>
        </header>

        <div class="progress">
          <div class="progress__bar">
            <div class="progress__fill" :style="{ width: `${progressPercent}%` }" />
          </div>
          <span class="progress__text">已答 {{ answeredCount }} / {{ paper.questions.length }}</span>
        </div>

        <ol class="questions">
          <li v-for="(q, idx) in paper.questions" :key="q.id" class="q">
            <div class="q__head">
              <span class="q__index">{{ idx + 1 }}</span>
              <p class="q__title">{{ q.title }}</p>
            </div>
            <div class="q__options">
              <button
                v-for="opt in q.options"
                :key="opt.key"
                type="button"
                class="opt"
                :class="{ 'opt--active': answers[q.id] === opt.key }"
                @click="choose(q.id, opt.key)"
              >
                <span class="opt__key">{{ opt.key }}</span>
                <span class="opt__text">{{ opt.text }}</span>
              </button>
            </div>
          </li>
        </ol>

        <div class="submit">
          <p v-if="!allAnswered" class="submit__hint">
            还有 {{ paper.questions.length - answeredCount }} 题没答，答完就能看到结果。
          </p>
          <AppButton
            block
            size="lg"
            icon="check"
            :disabled="!allAnswered"
            :loading="submitting"
            @click="onSubmit"
          >
            提交并查看结果
          </AppButton>
          <p class="submit__note">
            提交后结果会保存在「我的记录」里，可以随时回来查看。
          </p>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { fetchPaper, submitAssessment } from '../../api/assessment'
import type { AnswerItem, AssessmentPaper } from '../../api/types'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppEmpty from '../../components/ui/AppEmpty.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppSpinner from '../../components/ui/AppSpinner.vue'

const route = useRoute()
const router = useRouter()

const paper = ref<AssessmentPaper | null>(null)
const loading = ref(true)
const submitting = ref(false)
const answers = reactive<Record<string, string>>({})

const answeredCount = computed(() => Object.keys(answers).length)
const allAnswered = computed(
  () => !!paper.value && paper.value.questions.length > 0 && answeredCount.value >= paper.value.questions.length,
)
const progressPercent = computed(() => {
  const total = paper.value?.questions.length ?? 0
  return total === 0 ? 0 : Math.round((answeredCount.value / total) * 100)
})

function choose(questionId: string, optionKey: string): void {
  answers[questionId] = optionKey
}

async function onSubmit(): Promise<void> {
  if (!paper.value || !allAnswered.value || submitting.value) return
  const id = Number(route.params.id)
  const payload: AnswerItem[] = paper.value.questions.map((q) => ({
    questionId: q.id,
    optionKey: answers[q.id],
  }))
  submitting.value = true
  try {
    const result = await submitAssessment(id, payload)
    toast.success('已提交，正在为你生成结果')
    if (result && result.id) router.replace(`/assessment/result/${result.id}`)
    else router.replace('/me/records')
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '提交失败，请稍后再试')
  } finally {
    submitting.value = false
  }
}

onMounted(async () => {
  try {
    paper.value = await fetchPaper(Number(route.params.id))
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '题目加载失败')
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-5xl, 56px);
}
.container--paper {
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
  margin: var(--space-l) 0 var(--space-xl);
}
.head__title {
  font-size: clamp(22px, 3vw, 30px);
}
.head__sub {
  margin-top: var(--space-s);
  font-size: var(--font-m);
  line-height: 1.9;
  color: var(--text-2);
}

.progress {
  display: flex;
  align-items: center;
  gap: var(--space-l);
  padding: var(--space-l) 0;
  position: sticky;
  top: var(--header-h);
  z-index: 5;
  background: var(--bg);
}
.progress__bar {
  flex: 1;
  height: 8px;
  border-radius: var(--radius-full);
  background: var(--line-strong);
  overflow: hidden;
}
.progress__fill {
  height: 100%;
  border-radius: var(--radius-full);
  background: var(--primary);
  transition: width var(--motion-normal) var(--ease-standard);
}
.progress__text {
  flex: none;
  font-size: var(--font-s);
  color: var(--text-3);
}

.questions {
  display: flex;
  flex-direction: column;
  gap: var(--space-xl);
  list-style: none;
  margin: 0;
  padding: 0;
}
.q {
  padding: var(--space-xl) var(--space-2xl);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
}
.q__head {
  display: flex;
  gap: var(--space-m);
}
.q__index {
  flex: none;
  display: grid;
  place-items: center;
  width: 24px;
  height: 24px;
  border-radius: var(--radius-full);
  background: var(--primary-weak);
  color: var(--primary);
  font-size: var(--font-xs);
  font-weight: 700;
}
.q__title {
  font-size: var(--font-l);
  line-height: 1.75;
}
.q__options {
  display: flex;
  flex-direction: column;
  gap: var(--space-s);
  margin-top: var(--space-l);
  padding-left: 36px;
}
.opt {
  display: flex;
  align-items: center;
  gap: var(--space-m);
  padding: 11px 14px;
  border-radius: var(--radius-md);
  border: 1px solid var(--line-strong);
  background: var(--card);
  text-align: left;
  cursor: pointer;
  transition:
    border-color var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard);
}
.opt:hover {
  border-color: var(--primary-border);
  background: var(--bg-soft);
}
.opt--active {
  border-color: var(--primary);
  background: var(--primary-weak);
  box-shadow: 0 0 0 3px var(--primary-weak);
}
.opt__key {
  flex: none;
  display: grid;
  place-items: center;
  width: 24px;
  height: 24px;
  border-radius: var(--radius-full);
  border: 1px solid var(--line-strong);
  font-size: var(--font-xs);
  font-weight: 700;
  color: var(--text-3);
}
.opt--active .opt__key {
  background: var(--primary);
  border-color: var(--primary);
  color: var(--primary-contrast);
}
.opt__text {
  font-size: var(--font-m);
  line-height: 1.7;
  color: var(--text-2);
}
.opt--active .opt__text {
  color: var(--text);
}

.submit {
  margin-top: var(--space-3xl);
}
.submit__hint {
  margin-bottom: var(--space-m);
  font-size: var(--font-s);
  color: var(--text-3);
  text-align: center;
}
.submit__note {
  margin-top: var(--space-m);
  font-size: var(--font-xs);
  color: var(--text-3);
  text-align: center;
}
</style>
