<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { login } from '../api/admin'
import { setAuth } from '../auth'

const router = useRouter()
const route = useRoute()

const form = reactive({ username: '', password: '' })
const loading = ref(false)

async function onSubmit(): Promise<void> {
  if (!form.username.trim() || !form.password) {
    ElMessage.warning('请输入账号和密码')
    return
  }
  loading.value = true
  try {
    const res = await login(form.username.trim(), form.password)
    setAuth(res.token, res.username, res.role)
    ElMessage.success('登录成功')
    const redirect = (route.query.redirect as string) || '/dashboard'
    router.replace(redirect)
  } catch {
    /* 拦截器已提示 */
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login">
    <div class="grid" />
    <div class="glow glow-a" />
    <div class="glow glow-b" />
    <div class="glow glow-c" />

    <div class="login-card">
      <div class="card-sheen" />

      <div class="brand">
        <div class="brand-mark">M</div>
        <div>
          <div class="brand-name">MindHealth</div>
          <div class="brand-sub">ADMIN CONSOLE</div>
        </div>
      </div>

      <div class="headline">欢迎回来</div>
      <div class="subline">请使用管理员账号登录以继续</div>

      <el-form label-position="top" @submit.prevent>
        <el-form-item label="账号">
          <el-input v-model="form.username" size="large" placeholder="请输入管理员账号" clearable>
            <template #prefix>
              <el-icon><User /></el-icon>
            </template>
          </el-input>
        </el-form-item>
        <el-form-item label="密码">
          <el-input
            v-model="form.password"
            size="large"
            type="password"
            placeholder="请输入密码"
            show-password
            @keyup.enter="onSubmit"
          >
            <template #prefix>
              <el-icon><Lock /></el-icon>
            </template>
          </el-input>
        </el-form-item>

        <el-button type="primary" size="large" class="submit" :loading="loading" @click="onSubmit">
          登 录
        </el-button>
      </el-form>

      <div class="foot">
        <span class="dot" />
        仅限授权管理员访问 · 所有操作将被记录
      </div>
    </div>
  </div>
</template>

<style scoped>
.login {
  position: relative;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: radial-gradient(1100px 620px at 50% -12%, #16233c 0%, #0b1120 52%, #06080e 100%);
  overflow: hidden;
}

.grid {
  position: absolute;
  inset: 0;
  background-image: linear-gradient(rgba(255, 255, 255, 0.028) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.028) 1px, transparent 1px);
  background-size: 46px 46px;
  mask-image: radial-gradient(circle at 50% 40%, #000 0%, transparent 72%);
  -webkit-mask-image: radial-gradient(circle at 50% 40%, #000 0%, transparent 72%);
  pointer-events: none;
}

.glow {
  position: absolute;
  border-radius: 50%;
  filter: blur(100px);
  pointer-events: none;
}

.glow-a {
  width: 460px;
  height: 460px;
  top: -170px;
  left: -130px;
  background: rgba(77, 124, 254, 0.4);
}

.glow-b {
  width: 400px;
  height: 400px;
  bottom: -190px;
  right: -110px;
  background: rgba(34, 211, 197, 0.24);
}

.glow-c {
  width: 320px;
  height: 320px;
  top: 44%;
  left: 58%;
  background: rgba(139, 124, 255, 0.22);
}

.login-card {
  position: relative;
  width: 404px;
  max-width: 100%;
  padding: 34px 34px 26px;
  background: linear-gradient(160deg, rgba(28, 37, 56, 0.92) 0%, rgba(16, 22, 35, 0.94) 100%);
  border: 1px solid var(--border-strong);
  border-radius: 22px;
  box-shadow: 0 40px 90px -34px rgba(0, 0, 0, 0.95), 0 0 0 1px rgba(122, 158, 255, 0.08),
    inset 0 1px 0 rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(22px) saturate(150%);
  -webkit-backdrop-filter: blur(22px) saturate(150%);
  overflow: hidden;
}

.card-sheen {
  position: absolute;
  top: 0;
  left: 12%;
  right: 12%;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(147, 180, 255, 0.85), transparent);
}

.brand {
  display: flex;
  align-items: center;
  gap: 11px;
  margin-bottom: 26px;
}

.brand-mark {
  width: 42px;
  height: 42px;
  border-radius: 13px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 19px;
  font-weight: 700;
  color: #fff;
  background: linear-gradient(135deg, #4d7cfe 0%, #8b7cff 55%, #22d3c5 100%);
  box-shadow: 0 10px 26px -10px rgba(77, 124, 254, 0.95), inset 0 1px 0 rgba(255, 255, 255, 0.32);
}

.brand-name {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-1);
  line-height: 1.25;
  letter-spacing: 0.2px;
}

.brand-sub {
  font-size: 9px;
  letter-spacing: 1.8px;
  color: var(--text-3);
}

.headline {
  font-size: 24px;
  font-weight: 600;
  letter-spacing: 0.4px;
  background: linear-gradient(120deg, #ffffff 0%, #b9cdff 62%, #7ee7dc 100%);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.subline {
  margin-top: 6px;
  margin-bottom: 22px;
  font-size: 13px;
  color: var(--text-3);
}

.submit {
  width: 100%;
  margin-top: 6px;
  letter-spacing: 2px;
  height: 44px;
}

.foot {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  margin-top: 22px;
  font-size: 11px;
  color: var(--text-3);
}

.dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: #2ecc8f;
  box-shadow: 0 0 8px rgba(46, 204, 143, 0.9);
}
</style>
