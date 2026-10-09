<template>
  <div class="auth-card">
    <header class="auth-card__head">
      <h1 class="auth-card__title">创建账号</h1>
      <p class="auth-card__sub">一分钟就好。你的记录只属于你自己。</p>
    </header>

    <form class="auth-form" @submit.prevent="onSubmit">
      <AppInput
        v-model="values.phone"
        label="手机号"
        placeholder="请输入 11 位手机号"
        type="tel"
        icon="phone"
        autocomplete="tel"
        :maxlength="11"
        :error="errors.phone"
        @blur="form.validateField('phone')"
      />

      <AppInput
        v-model="values.password"
        label="密码"
        placeholder="6-32 位，建议字母加数字"
        :type="reveal ? 'text' : 'password'"
        icon="lock"
        autocomplete="new-password"
        :maxlength="32"
        :error="errors.password"
        @blur="form.validateField('password')"
      >
        <template #suffix>
          <button
            type="button"
            class="reveal"
            :aria-label="reveal ? '隐藏密码' : '显示密码'"
            @click="reveal = !reveal"
          >
            <AppIcon :name="reveal ? 'eye-off' : 'eye'" :size="17" />
          </button>
        </template>
      </AppInput>

      <AppInput
        v-model="values.confirmPassword"
        label="确认密码"
        placeholder="请再次输入密码"
        type="password"
        icon="shield"
        autocomplete="new-password"
        :maxlength="32"
        :error="errors.confirmPassword"
        @blur="form.validateField('confirmPassword')"
      />

      <p class="auth-form__note">
        注册即表示你已阅读并同意我们以「不评判、只陪伴」的方式为你提供服务。
      </p>

      <AppButton type="submit" size="lg" block :loading="submitting" icon="sparkles">注册并进入</AppButton>
    </form>

    <p class="auth-card__foot">
      已经有账号了？
      <RouterLink to="/login" class="auth-card__link">直接登录</RouterLink>
    </p>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useForm, rules } from '../../composables/useForm'
import { useAuthStore } from '../../stores/auth'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppInput from '../../components/ui/AppInput.vue'

const auth = useAuthStore()
const router = useRouter()

const reveal = ref(false)
const submitting = ref(false)

const form = useForm(
  reactive({ phone: '', password: '', confirmPassword: '' }),
  {
    phone: rules.phone(),
    password: rules.password(),
    confirmPassword: {
      required: true,
      validate: (value: string): string =>
        value === form.values.password ? '' : '两次输入的密码不一致',
      message: '请再次输入密码',
    },
  },
)
const { values, errors } = form

async function onSubmit(): Promise<void> {
  if (!form.validate()) return
  submitting.value = true
  try {
    await auth.register(values.phone.trim(), values.password, values.confirmPassword)
    // 注册成功后直接登录，省掉一次重复输入
    await auth.login(values.phone.trim(), values.password)
    toast.success('欢迎加入轻心')
    await router.replace('/')
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    if (message) toast.error(message)
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.auth-card {
  width: 100%;
  max-width: 400px;
  padding: var(--space-3xl) var(--space-2xl);
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-md);
}
.auth-card__head {
  margin-bottom: var(--space-3xl);
}
.auth-card__title {
  font-size: var(--font-page-title);
}
.auth-card__sub {
  margin-top: var(--space-s);
  font-size: var(--font-m);
  color: var(--text-3);
  line-height: 1.8;
}
.auth-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-l);
}
.auth-form__note {
  font-size: var(--font-xs);
  line-height: 1.8;
  color: var(--text-3);
}
.reveal {
  display: inline-flex;
  align-items: center;
  background: none;
  border: none;
  padding: 2px;
  cursor: pointer;
  color: inherit;
  transition: color var(--motion-fast) var(--ease-standard);
}
.reveal:hover {
  color: var(--primary);
}
.auth-card__foot {
  margin-top: var(--space-2xl);
  font-size: var(--font-m);
  color: var(--text-3);
}
.auth-card__link {
  color: var(--primary);
  font-weight: 600;
}
.auth-card__link:hover {
  text-decoration: underline;
}
</style>
