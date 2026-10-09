<template>
  <div class="auth-card">
    <header class="auth-card__head">
      <h1 class="auth-card__title">欢迎回来</h1>
      <p class="auth-card__sub">继续记录你的心情，树洞一直在这里。</p>
    </header>

    <form class="auth-form" @submit.prevent="onSubmit">
      <AppInput
        v-model="values.phone"
        label="手机号"
        placeholder="请输入手机号"
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
        placeholder="请输入密码"
        :type="reveal ? 'text' : 'password'"
        icon="lock"
        autocomplete="current-password"
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

      <AppButton type="submit" size="lg" block :loading="submitting" icon="arrow-right">登录</AppButton>
    </form>

    <p class="auth-card__foot">
      还没有账号？
      <RouterLink to="/register" class="auth-card__link">免费注册</RouterLink>
    </p>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { useForm, rules } from '../../composables/useForm'
import { useAuthStore } from '../../stores/auth'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppInput from '../../components/ui/AppInput.vue'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const reveal = ref(false)
const submitting = ref(false)

const form = useForm(reactive({ phone: '', password: '' }), {
  phone: rules.phone(),
  password: rules.required('请输入密码'),
})
const { values, errors } = form

async function onSubmit(): Promise<void> {
  if (!form.validate()) return
  submitting.value = true
  try {
    await auth.login(values.phone.trim(), values.password)
    toast.success('欢迎回来')
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/'
    await router.replace(redirect)
  } catch (err) {
    // http 层已把 5001（手机号或密码错误）等业务文案提示出来；
    // 这里只在错误未携带提示时兜底，避免重复弹两条。
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
.auth-form :deep(.app-button) {
  margin-top: var(--space-s);
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
