<template>
  <div class="page">
    <div class="container container--form">
      <RouterLink to="/me" class="back">
        <AppIcon name="arrow-left" :size="16" />
        返回我的
      </RouterLink>

      <header class="head">
        <h1 class="head__title">意见反馈</h1>
        <p class="head__sub">你的每一句话，都会帮助我们把它做得更好。</p>
      </header>

      <div v-if="submitted" class="done">
        <div class="done__icon">
          <AppIcon name="check" :size="28" />
        </div>
        <h2 class="done__title">已收到你的反馈</h2>
        <p class="done__text">谢谢你的耐心，我们会认真读完每一条。</p>
        <div class="done__actions">
          <AppButton kind="secondary" @click="resetAll">再写一条</AppButton>
          <AppButton @click="router.push('/me')">返回我的</AppButton>
        </div>
      </div>

      <form v-else class="form" @submit.prevent="onSubmit">
        <div class="block">
          <span class="block__label">反馈类型</span>
          <div class="types">
            <button
              v-for="t in TYPES"
              :key="t.value"
              type="button"
              class="type"
              :class="{ 'type--active': form.values.type === t.value }"
              @click="form.values.type = t.value"
            >
              <AppIcon :name="t.icon" :size="16" />
              {{ t.label }}
            </button>
          </div>
        </div>

        <AppTextarea
          v-model="form.values.content"
          label="想说的话"
          :rows="7"
          :maxlength="1000"
          show-count
          placeholder="说说遇到的问题，或者你希望有的功能…"
          :error="form.errors.content"
          @blur="form.validateField('content')"
        />

        <AppInput
          v-model="form.values.contact"
          label="联系方式（可选）"
          placeholder="留下手机号或邮箱，方便我们回复你"
          icon="phone"
          :maxlength="60"
        />

        <div class="actions">
          <AppButton kind="secondary" native-type="button" @click="router.push('/me')">取消</AppButton>
          <AppButton native-type="submit" :loading="saving" icon="send">提交反馈</AppButton>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { submitFeedback } from '../../api/feedback'
import type { FeedbackType } from '../../api/types'
import { useForm, rules } from '../../composables/useForm'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppInput from '../../components/ui/AppInput.vue'
import AppTextarea from '../../components/ui/AppTextarea.vue'

const TYPES: { value: FeedbackType; label: string; icon: string }[] = [
  { value: 'bug', label: '问题反馈', icon: 'alert' },
  { value: 'suggestion', label: '功能建议', icon: 'sparkles' },
  { value: 'other', label: '其他', icon: 'message' },
]

const router = useRouter()

const saving = ref(false)
const submitted = ref(false)

const form = useForm(
  { type: 'suggestion', content: '', contact: '' },
  {
    content: { ...rules.required('说点什么再提交吧'), max: 1000, message: '最多 1000 个字符' },
  },
)

async function onSubmit(): Promise<void> {
  if (!form.validate()) return
  saving.value = true
  try {
    await submitFeedback({
      content: form.values.content.trim(),
      type: form.values.type as FeedbackType,
      contact: form.values.contact.trim() || undefined,
    })
    submitted.value = true
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '提交失败，请稍后再试')
  } finally {
    saving.value = false
  }
}

function resetAll(): void {
  form.reset({ type: 'suggestion', content: '', contact: '' })
  submitted.value = false
}
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-4xl);
}
.container--form {
  max-width: 640px;
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
.types {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-s);
}
.type {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  height: 46px;
  border-radius: var(--radius-md);
  border: 1px solid var(--line-strong);
  background: var(--card);
  color: var(--text-2);
  font-size: var(--font-m);
  cursor: pointer;
  transition:
    transform var(--motion-fast) var(--ease-standard),
    border-color var(--motion-fast) var(--ease-standard),
    box-shadow var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard);
}
.type:hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
  color: var(--primary);
}
.type--active {
  background: var(--primary-weak);
  border-color: var(--primary-border);
  color: var(--primary);
  font-weight: 600;
}

.actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-m);
  padding-top: var(--space-s);
}

.done {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: var(--space-4xl) var(--space-xl);
  border-radius: var(--radius-xl);
  background: var(--bg-soft);
  border: 1px solid var(--line);
}
.done__icon {
  display: grid;
  place-items: center;
  width: 64px;
  height: 64px;
  border-radius: var(--radius-full);
  background: var(--primary-weak);
  color: var(--primary);
  margin-bottom: var(--space-l);
}
.done__title {
  font-size: var(--font-2xl);
}
.done__text {
  margin-top: var(--space-s);
  font-size: var(--font-m);
  color: var(--text-2);
}
.done__actions {
  display: flex;
  gap: var(--space-m);
  margin-top: var(--space-2xl);
}

@media (max-width: 560px) {
  .types {
    grid-template-columns: 1fr;
  }
}
</style>
