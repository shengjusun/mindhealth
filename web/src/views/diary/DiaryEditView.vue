<template>
  <div class="page">
    <div class="container container--form">
      <RouterLink :to="backTo" class="back">
        <AppIcon name="arrow-left" :size="16" />
        返回
      </RouterLink>

      <header class="head">
        <h1 class="head__title">{{ isEdit ? '编辑这篇日记' : '写一篇日记' }}</h1>
        <p class="head__sub">想写什么就写什么，只有你自己看得到。</p>
      </header>

      <div v-if="loading" class="loading">
        <AppSpinner />
      </div>

      <form v-else class="form" @submit.prevent="onSubmit">
        <AppInput
          v-model="form.values.title"
          label="标题"
          placeholder="给今天起一个名字"
          :error="form.errors.title"
          :maxlength="60"
          @blur="form.validateField('title')"
        />

        <div class="block">
          <span class="block__label">此刻的情绪</span>
          <div class="emotions">
            <button
              v-for="e in EMOTIONS"
              :key="e"
              type="button"
              class="emotion"
              :class="{ 'emotion--active': form.values.emotion === e }"
              @click="form.values.emotion = e"
            >
              <span class="emotion__emoji">{{ emotionEmoji(e) }}</span>
              <span class="emotion__name">{{ e }}</span>
            </button>
          </div>
        </div>

        <div class="block">
          <div class="block__row">
            <span class="block__label">情绪强度</span>
            <span class="block__value">{{ intensity }} / 10 · {{ softIntensity(intensity) }}</span>
          </div>
          <input
            v-model.number="intensity"
            class="range"
            type="range"
            min="0"
            max="10"
            step="1"
            :style="{ '--percent': `${intensity * 10}%` }"
          />
        </div>

        <AppInput
          v-model="form.values.event"
          label="发生了什么（可选）"
          placeholder="比如：和同事的一次谈话"
          icon="calendar"
          :maxlength="60"
        />

        <AppTextarea
          v-model="form.values.content"
          label="正文"
          :rows="9"
          :maxlength="2000"
          show-count
          placeholder="慢慢写，没人催你…"
          :error="form.errors.content"
          :hint="form.errors.content ? '' : '写下来，情绪就已经被接住一半了。'"
          @blur="form.validateField('content')"
        />

        <div class="actions">
          <AppButton kind="secondary" type="button" native-type="button" @click="onCancel">取消</AppButton>
          <AppButton native-type="submit" :loading="saving" icon="check">
            {{ isEdit ? '保存修改' : '保存日记' }}
          </AppButton>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { createDiary, getDiary, updateDiary } from '../../api/diary'
import { EMOTIONS, emotionEmoji, softIntensity } from '../../utils/format'
import { useForm, rules } from '../../composables/useForm'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppInput from '../../components/ui/AppInput.vue'
import AppSpinner from '../../components/ui/AppSpinner.vue'
import AppTextarea from '../../components/ui/AppTextarea.vue'

const route = useRoute()
const router = useRouter()

const editId = computed(() => (route.params.id ? Number(route.params.id) : null))
const isEdit = computed(() => editId.value !== null)
const backTo = computed(() => (isEdit.value ? `/diary/${editId.value}` : '/diary'))

const loading = ref(false)
const saving = ref(false)
const intensity = ref(5)

const form = useForm(
  { title: '', content: '', emotion: '平静', event: '' },
  {
    title: { ...rules.required('给今天起个名字吧'), max: 60, message: '标题最多 60 个字符' },
    content: { ...rules.required('写点什么，哪怕一句话'), max: 2000, message: '正文最多 2000 个字符' },
  },
)

async function load(): Promise<void> {
  if (!isEdit.value || editId.value === null) return
  loading.value = true
  try {
    const d = await getDiary(editId.value)
    form.reset({
      title: d.title ?? '',
      content: d.content ?? '',
      emotion: d.emotion || '平静',
      event: d.event ?? '',
    })
    intensity.value = typeof d.intensity === 'number' ? d.intensity : 5
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '日记加载失败')
    router.replace('/diary')
  } finally {
    loading.value = false
  }
}

async function onSubmit(): Promise<void> {
  if (!form.validate()) return
  saving.value = true
  const payload = {
    title: form.values.title.trim(),
    content: form.values.content.trim(),
    emotion: form.values.emotion,
    intensity: intensity.value,
    event: form.values.event.trim(),
  }
  try {
    if (isEdit.value && editId.value !== null) {
      await updateDiary(editId.value, payload)
      toast.success('已保存修改')
      router.replace(`/diary/${editId.value}`)
    } else {
      const created = await createDiary(payload)
      toast.success('日记已保存')
      if (created && created.id) router.replace(`/diary/${created.id}`)
      else router.replace('/diary')
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '保存失败，请稍后再试')
  } finally {
    saving.value = false
  }
}

function onCancel(): void {
  router.push(backTo.value)
}

onMounted(load)
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-4xl);
}
.container--form {
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
.loading {
  display: grid;
  place-items: center;
  padding: var(--space-4xl) 0;
}

.form {
  display: flex;
  flex-direction: column;
  gap: var(--space-xl);
}

.block {
  display: flex;
  flex-direction: column;
  gap: var(--space-m);
}
.block__label {
  font-size: var(--font-s);
  font-weight: 600;
  color: var(--text-2);
}
.block__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-m);
}
.block__value {
  font-size: var(--font-s);
  color: var(--text-3);
}

.emotions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-s);
}
.emotion {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 9px 16px;
  border-radius: var(--radius-full);
  border: 1px solid var(--line-strong);
  background: var(--card);
  box-shadow: var(--shadow-sm);
  cursor: pointer;
  transition:
    transform var(--motion-fast) var(--ease-standard),
    border-color var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard),
    box-shadow var(--motion-fast) var(--ease-standard);
}
.emotion:hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.emotion--active {
  background: var(--primary-weak);
  border-color: var(--primary);
}
.emotion__emoji {
  font-size: 17px;
}
.emotion__name {
  font-size: var(--font-m);
  color: var(--text-2);
}
.emotion--active .emotion__name {
  color: var(--primary);
  font-weight: 600;
}

.range {
  -webkit-appearance: none;
  appearance: none;
  width: 100%;
  height: 6px;
  border-radius: var(--radius-full);
  background: linear-gradient(
    to right,
    var(--primary) 0%,
    var(--primary) var(--percent),
    var(--line-strong) var(--percent),
    var(--line-strong) 100%
  );
  outline: none;
  cursor: pointer;
}
.range::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--card);
  border: 3px solid var(--primary);
  box-shadow: var(--shadow-sm);
  transition: transform var(--motion-fast) var(--ease-standard);
}
.range::-webkit-slider-thumb:hover {
  transform: scale(1.12);
}
.range::-moz-range-thumb {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--card);
  border: 3px solid var(--primary);
}

.actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-m);
  padding-top: var(--space-s);
}
</style>
