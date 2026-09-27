<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import type { FormInstance, FormRules } from 'element-plus'
import { changePassword, fetchProfile, type AdminProfile } from '../api/admin'
import { getAdminName, getAdminRole, markPasswordChanged } from '../auth'
import { formatRole, formatTime } from '../utils/format'

const loading = ref(false)
const profile = ref<AdminProfile | null>(null)

const displayName = computed(() => profile.value?.username || getAdminName() || '-')
const initial = computed(() => displayName.value.charAt(0).toUpperCase())
const roleText = computed(() => formatRole(profile.value?.role || getAdminRole()))

const formRef = ref<FormInstance>()
const pwd = reactive({ oldPassword: '', newPassword: '', confirmPassword: '' })
const submitting = ref(false)

const rules: FormRules = {
  oldPassword: [{ required: true, message: '请输入当前密码', trigger: 'blur' }],
  newPassword: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 6, max: 64, message: '密码长度需为 6~64 位', trigger: 'blur' },
  ],
  confirmPassword: [{ required: true, message: '请再次输入新密码', trigger: 'blur' }],
}

const mismatch = computed(
  () => pwd.confirmPassword.length > 0 && pwd.confirmPassword !== pwd.newPassword,
)
const sameAsOld = computed(
  () =>
    pwd.oldPassword.length > 0 &&
    pwd.newPassword.length > 0 &&
    pwd.oldPassword === pwd.newPassword,
)

async function loadProfile(): Promise<void> {
  loading.value = true
  try {
    profile.value = await fetchProfile()
  } catch {
    /* 拦截器已提示 */
  } finally {
    loading.value = false
  }
}

function onReset(): void {
  pwd.oldPassword = ''
  pwd.newPassword = ''
  pwd.confirmPassword = ''
  formRef.value?.clearValidate()
}

async function onSubmit(): Promise<void> {
  if (!formRef.value) return
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return
  if (mismatch.value) {
    ElMessage.warning('两次输入的新密码不一致')
    return
  }
  if (sameAsOld.value) {
    ElMessage.warning('新密码不能与当前密码相同')
    return
  }
  submitting.value = true
  try {
    await changePassword(pwd.oldPassword, pwd.newPassword)
    // 撤掉顶部「仍在使用初始密码」提示条
    markPasswordChanged()
    ElMessage.success('密码修改成功')
    onReset()
  } catch {
    /* 拦截器已提示 */
  } finally {
    submitting.value = false
  }
}

onMounted(loadProfile)
</script>

<template>
  <div class="page">
    <div class="grid">
      <div v-loading="loading" class="panel">
        <div class="panel__head">
          <span class="panel__title">账号信息</span>
          <div class="spacer" />
          <el-button size="small" text type="primary" @click="loadProfile">刷新</el-button>
        </div>
        <div class="panel__body">
          <div class="hero">
            <div class="hero-avatar">{{ initial }}</div>
            <div class="hero-meta">
              <div class="hero-name">{{ displayName }}</div>
              <div class="hero-role">{{ roleText }}</div>
            </div>
          </div>

          <ul class="facts">
            <li>
              <span>账号 ID</span>
              <b>{{ profile?.id ?? '-' }}</b>
            </li>
            <li>
              <span>用户名</span>
              <b>{{ profile?.username ?? '-' }}</b>
            </li>
            <li>
              <span>角色</span>
              <b>{{ roleText }}</b>
            </li>
            <li>
              <span>创建时间</span>
              <b>{{ formatTime(profile?.createTime) }}</b>
            </li>
          </ul>
        </div>
      </div>

      <div class="panel">
        <div class="panel__head">
          <span class="panel__title">修改密码</span>
        </div>
        <div class="panel__body">
          <el-form ref="formRef" :model="pwd" :rules="rules" label-width="96px" @submit.prevent>
            <el-form-item label="当前密码" prop="oldPassword">
              <el-input
                v-model="pwd.oldPassword"
                type="password"
                show-password
                placeholder="请输入当前登录密码"
              />
            </el-form-item>
            <el-form-item label="新密码" prop="newPassword">
              <el-input
                v-model="pwd.newPassword"
                type="password"
                show-password
                placeholder="6~64 位字符"
              />
            </el-form-item>
            <el-form-item label="确认新密码" prop="confirmPassword">
              <el-input
                v-model="pwd.confirmPassword"
                type="password"
                show-password
                placeholder="请再次输入新密码"
              />
            </el-form-item>

            <div class="hint" :class="{ 'hint-error': mismatch || sameAsOld }">
              <template v-if="mismatch">两次输入的新密码不一致</template>
              <template v-else-if="sameAsOld">新密码不能与当前密码相同</template>
              <template v-else>密码修改后立即生效，请妥善保管新密码。</template>
            </div>

            <el-form-item>
              <el-button type="primary" :loading="submitting" @click="onSubmit">
                保存修改
              </el-button>
              <el-button @click="onReset">重置</el-button>
            </el-form-item>
          </el-form>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.grid {
  display: grid;
  grid-template-columns: minmax(300px, 370px) minmax(0, 1fr);
  gap: 16px;
  align-items: start;
}

@media (max-width: 1080px) {
  .grid {
    grid-template-columns: minmax(0, 1fr);
  }
}

.hero {
  display: flex;
  align-items: center;
  gap: 14px;
  padding-bottom: 18px;
  margin-bottom: 4px;
  border-bottom: 1px solid var(--border);
}

.hero-avatar {
  width: 52px;
  height: 52px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
  font-weight: 600;
  color: #fff;
  background: linear-gradient(135deg, var(--brand-500) 0%, var(--brand-teal) 100%);
  box-shadow: 0 10px 22px -10px rgba(59, 111, 245, 0.85);
  flex: none;
}

.hero-name {
  font-size: 17px;
  font-weight: 600;
  color: var(--text-1);
  line-height: 1.3;
}

.hero-role {
  font-size: 12px;
  color: var(--text-3);
}

.facts {
  margin: 0;
  padding: 0;
  list-style: none;
}

.facts li {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 0;
  border-bottom: 1px dashed var(--border);
}

.facts li:last-child {
  border-bottom: none;
  padding-bottom: 0;
}

.facts span {
  font-size: 13px;
  color: var(--text-3);
}

.facts b {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  font-variant-numeric: tabular-nums;
}

.hint {
  margin: 0 0 18px 96px;
  font-size: 12px;
  color: var(--text-3);
}

.hint-error {
  color: var(--el-color-danger);
}
</style>
