<template>
  <div class="page">
    <div class="container container--form">
      <RouterLink to="/me" class="back">
        <AppIcon name="arrow-left" :size="16" />
        返回我的
      </RouterLink>

      <header class="head">
        <h1 class="head__title">个人资料</h1>
        <p class="head__sub">这些信息只用来让陪伴更贴近你，不会对外公开。</p>
      </header>

      <div v-if="loading" class="loading">
        <AppSpinner />
      </div>

      <form v-else class="form" @submit.prevent="onSubmit">
        <div class="avatar-row">
          <div class="avatar">
            <img v-if="avatarPath" :src="avatarPath" alt="头像" />
            <span v-else class="avatar__initial">{{ initial }}</span>
          </div>
          <div class="avatar__side">
            <AppButton kind="secondary" size="sm" icon="image" :loading="uploading" @click="pickFile">
              更换头像
            </AppButton>
            <p class="avatar__hint">支持 JPG / PNG / WEBP，不超过 5MB</p>
          </div>
          <input ref="fileInput" class="file" type="file" accept="image/*" @change="onPick" />
        </div>

        <AppInput
          v-model="form.values.nickname"
          label="昵称"
          placeholder="想让别人怎么称呼你"
          icon="user"
          :maxlength="20"
          :error="form.errors.nickname"
          hint="最多 20 个字符"
          @blur="form.validateField('nickname')"
        />

        <div class="two">
          <AppInput
            v-model="form.values.age"
            label="年龄"
            placeholder="选填"
            icon="calendar"
            :maxlength="3"
            :error="form.errors.age"
            @blur="form.validateField('age')"
          />
          <div class="block">
            <span class="block__label">性别</span>
            <div class="gender">
              <button
                v-for="g in GENDERS"
                :key="g.value"
                type="button"
                class="gender__item"
                :class="{ 'gender__item--active': form.values.gender === g.value }"
                @click="form.values.gender = g.value"
              >
                {{ g.label }}
              </button>
            </div>
          </div>
        </div>

        <AppTextarea
          v-model="form.values.signature"
          label="个性签名"
          :rows="3"
          :maxlength="100"
          show-count
          placeholder="写一句想对自己说的话…"
        />

        <div class="actions">
          <AppButton kind="secondary" native-type="button" @click="router.push('/me')">取消</AppButton>
          <AppButton native-type="submit" :loading="saving" icon="check">保存</AppButton>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { fetchUserInfo, updateUser, uploadAvatar } from '../../api/user'
import { useAuthStore } from '../../stores/auth'
import { useForm } from '../../composables/useForm'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppInput from '../../components/ui/AppInput.vue'
import AppSpinner from '../../components/ui/AppSpinner.vue'
import AppTextarea from '../../components/ui/AppTextarea.vue'

const GENDERS = [
  { value: 'male', label: '男' },
  { value: 'female', label: '女' },
  { value: 'hidden', label: '保密' },
] as const

const router = useRouter()
const auth = useAuthStore()

const loading = ref(true)
const saving = ref(false)
const uploading = ref(false)
const avatarPath = ref('')
const fileInput = ref<HTMLInputElement | null>(null)

const form = useForm(
  { nickname: '', age: '', gender: 'hidden', signature: '' },
  {
    nickname: { required: true, max: 20, message: '昵称不能为空且最多 20 个字符' },
    age: {
      pattern: /^\d{1,3}$/,
      message: '年龄请填 1-3 位数字',
      validate: (v) => {
        const n = Number(v)
        return n >= 1 && n <= 120 ? '' : '年龄看起来不太对'
      },
    },
  },
)

const initial = computed(() => (form.values.nickname || auth.displayName).slice(0, 1) || '轻')

function pickFile(): void {
  fileInput.value?.click()
}

async function onPick(ev: Event): Promise<void> {
  const input = ev.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  if (!file.type.startsWith('image/')) {
    toast.error('请选择图片文件')
    return
  }
  if (file.size > 5 * 1024 * 1024) {
    toast.error('图片不能超过 5MB')
    return
  }
  uploading.value = true
  try {
    const path = await uploadAvatar(file)
    avatarPath.value = path
    toast.success('头像已上传，保存后生效')
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '头像上传失败，请稍后再试')
  } finally {
    uploading.value = false
  }
}

async function load(): Promise<void> {
  try {
    const info = await fetchUserInfo()
    form.reset({
      nickname: info.nickname ?? '',
      age: info.age === null || info.age === undefined ? '' : String(info.age),
      gender: info.gender ?? 'hidden',
      signature: info.signature ?? '',
    })
    avatarPath.value = info.avatar ?? ''
    if (info.avatar) auth.user && (auth.user.avatar = info.avatar)
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '资料加载失败')
  } finally {
    loading.value = false
  }
}

async function onSubmit(): Promise<void> {
  if (!form.validate()) return
  saving.value = true
  const ageText = form.values.age.trim()
  try {
    await updateUser({
      nickname: form.values.nickname.trim(),
      age: ageText ? Number(ageText) : null,
      gender: form.values.gender as 'male' | 'female' | 'hidden',
      avatar: avatarPath.value,
      signature: form.values.signature.trim(),
    })
    await auth.refreshProfile()
    toast.success('资料已更新')
    router.push('/me')
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '保存失败，请稍后再试')
  } finally {
    saving.value = false
  }
}

onMounted(load)
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

.avatar-row {
  display: flex;
  align-items: center;
  gap: var(--space-xl);
}
.avatar {
  display: grid;
  place-items: center;
  width: 84px;
  height: 84px;
  border-radius: var(--radius-full);
  overflow: hidden;
  background: var(--card);
  border: 2px solid var(--primary-border);
  flex: none;
}
.avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.avatar__initial {
  font-size: 32px;
  font-weight: 700;
  color: var(--primary);
}
.avatar__side {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.avatar__hint {
  font-size: var(--font-xs);
  color: var(--text-3);
}
.file {
  display: none;
}

.two {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-l);
}
.block {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.block__label {
  font-size: var(--font-s);
  font-weight: 600;
  color: var(--text-2);
}
.gender {
  display: flex;
  gap: var(--space-s);
}
.gender__item {
  flex: 1;
  height: 46px;
  border-radius: var(--radius-md);
  border: 1px solid var(--line-strong);
  background: var(--card);
  color: var(--text-2);
  font-size: var(--font-m);
  cursor: pointer;
  transition:
    border-color var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard);
}
.gender__item:hover {
  border-color: var(--primary-border);
  color: var(--primary);
}
.gender__item--active {
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

@media (max-width: 560px) {
  .two {
    grid-template-columns: 1fr;
  }
}
</style>
