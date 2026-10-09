<template>
  <div class="page">
    <div class="container container--narrow">
      <RouterLink to="/me" class="back">
        <AppIcon name="arrow-left" :size="16" />
        返回我的
      </RouterLink>

      <header class="head">
        <h1 class="head__title">设置</h1>
        <p class="head__sub">让界面更贴合你的习惯。</p>
      </header>

      <section class="card">
        <h2 class="card__title">外观模式</h2>
        <p class="card__sub">默认跟随系统，也可以手动固定。</p>
        <div class="seg">
          <button
            v-for="m in MODE_OPTIONS"
            :key="m.value"
            type="button"
            class="seg__item"
            :class="{ 'seg__item--active': theme.mode === m.value }"
            @click="theme.setMode(m.value)"
          >
            <AppIcon :name="m.icon" :size="16" />
            {{ m.label }}
          </button>
        </div>
      </section>

      <section class="card">
        <h2 class="card__title">主题色</h2>
        <p class="card__sub">选一个让眼睛舒服的颜色。</p>
        <div class="themes">
          <button
            v-for="t in THEME_OPTIONS"
            :key="t.id"
            type="button"
            class="theme"
            :class="{ 'theme--active': theme.themeId === t.id }"
            @click="theme.setThemeId(t.id)"
          >
            <span class="theme__swatch" :style="{ background: t.swatch }">
              <AppIcon v-if="theme.themeId === t.id" name="check" :size="14" />
            </span>
            <span class="theme__text">
              <span class="theme__name">{{ t.name }}</span>
              <span class="theme__desc">{{ t.desc }}</span>
            </span>
          </button>
        </div>
      </section>

      <section class="card">
        <h2 class="card__title">账号</h2>
        <div class="row">
          <div class="row__text">
            <span class="row__label">当前账号</span>
            <span class="row__value">{{ maskedPhone || '—' }}</span>
          </div>
        </div>
        <div class="row row--action">
          <div class="row__text">
            <span class="row__label">退出登录</span>
            <span class="row__value">退出后需要重新登录才能继续使用</span>
          </div>
          <AppButton kind="danger" size="sm" icon="logout" @click="confirmLogout = true">退出</AppButton>
        </div>
      </section>

      <p class="foot">轻心 · 你的情绪陪伴</p>
    </div>

    <AppModal v-model="confirmLogout" title="确定退出登录？" width="400">
      <p class="modal-text">退出后需要重新登录才能查看你的日记与测评记录。</p>
      <template #footer>
        <AppButton kind="secondary" @click="confirmLogout = false">再想想</AppButton>
        <AppButton kind="danger" @click="doLogout">退出登录</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { useThemeStore, THEME_OPTIONS, type ThemeMode } from '../../stores/theme'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppModal from '../../components/ui/AppModal.vue'

const MODE_OPTIONS: { value: ThemeMode; label: string; icon: string }[] = [
  { value: 'auto', label: '跟随系统', icon: 'monitor' },
  { value: 'light', label: '浅色', icon: 'sun' },
  { value: 'dark', label: '深色', icon: 'moon' },
]

const router = useRouter()
const auth = useAuthStore()
const theme = useThemeStore()

const confirmLogout = ref(false)

const maskedPhone = computed(() => {
  const p = auth.user?.phone || ''
  return p.length === 11 ? `${p.slice(0, 3)}****${p.slice(7)}` : p
})

function doLogout(): void {
  confirmLogout.value = false
  auth.logout()
  toast.success('已退出登录')
  router.replace('/')
}
</script>

<style scoped>
.page {
  padding: var(--space-3xl) 0 var(--space-4xl);
}
.container--narrow {
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

.card {
  padding: var(--space-2xl);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
  margin-bottom: var(--space-l);
}
.card__title {
  font-size: var(--font-xl);
}
.card__sub {
  margin-top: 4px;
  font-size: var(--font-s);
  color: var(--text-3);
}

.seg {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-s);
  margin-top: var(--space-l);
}
.seg__item {
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
    border-color var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard);
}
.seg__item:hover {
  border-color: var(--primary-border);
  color: var(--primary);
}
.seg__item--active {
  background: var(--primary-weak);
  border-color: var(--primary-border);
  color: var(--primary);
  font-weight: 600;
}

.themes {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-l);
  margin-top: var(--space-l);
}
.theme {
  display: flex;
  align-items: center;
  gap: var(--space-m);
  padding: var(--space-l);
  border-radius: var(--radius-lg);
  border: 1px solid var(--line-strong);
  background: var(--card);
  cursor: pointer;
  text-align: left;
  transition:
    transform var(--motion-normal) var(--ease-emphasized),
    border-color var(--motion-normal) var(--ease-standard),
    box-shadow var(--motion-normal) var(--ease-standard);
}
.theme:hover {
  transform: translateY(-3px);
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
}
.theme--active {
  background: var(--primary-weak);
  border-color: var(--primary-border);
}
.theme__swatch {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border-radius: var(--radius-full);
  color: #fff;
  flex: none;
  box-shadow: inset 0 0 0 1px var(--line);
}
.theme__text {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.theme__name {
  font-size: var(--font-m);
  font-weight: 600;
}
.theme__desc {
  font-size: var(--font-xs);
  color: var(--text-3);
}

.row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-l);
  padding: var(--space-l) 0;
  border-top: 1px solid var(--line);
  margin-top: var(--space-l);
}
.row--action + .row--action {
  border-top: 1px solid var(--line);
}
.row__text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.row__label {
  font-size: var(--font-m);
  font-weight: 600;
}
.row__value {
  font-size: var(--font-s);
  color: var(--text-3);
}

.foot {
  margin-top: var(--space-2xl);
  text-align: center;
  font-size: var(--font-xs);
  color: var(--text-3);
}

.modal-text {
  font-size: var(--font-m);
  line-height: 1.9;
  color: var(--text-2);
}

@media (max-width: 640px) {
  .themes,
  .seg {
    grid-template-columns: 1fr;
  }
}
</style>
