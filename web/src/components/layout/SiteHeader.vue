<template>
  <header class="site-header" :class="{ 'site-header--scrolled': scrolled }">
    <div class="site-header__inner container">
      <RouterLink to="/" class="brand" @click="menuOpen = false">
        <span class="brand__mark"><AppIcon name="leaf" :size="20" /></span>
        <span class="brand__text">轻心</span>
      </RouterLink>

      <nav class="nav" :class="{ 'nav--open': menuOpen }">
        <RouterLink
          v-for="item in NAV"
          :key="item.to"
          :to="item.to"
          class="nav__link"
          :class="{ 'nav__link--active': isActive(item.to) }"
          @click="menuOpen = false"
        >
          {{ item.label }}
        </RouterLink>
      </nav>

      <div class="actions">
        <ThemeToggle />

        <template v-if="auth.isLoggedIn">
          <div ref="userWrap" class="user">
            <button class="user__trigger" type="button" @click.stop="dropdownOpen = !dropdownOpen">
              <img v-if="auth.avatar" class="user__avatar" :src="auth.avatar" alt="" />
              <span v-else class="user__avatar user__avatar--fallback">{{ initial }}</span>
              <span class="user__name">{{ auth.displayName }}</span>
              <AppIcon name="chevron-down" :size="15" />
            </button>

            <Transition name="fade-up">
              <div v-if="dropdownOpen" class="menu">
                <RouterLink v-for="item in USER_MENU" :key="item.to" :to="item.to" class="menu__item" @click="dropdownOpen = false">
                  <AppIcon :name="item.icon" :size="16" />
                  <span>{{ item.label }}</span>
                </RouterLink>
                <div class="menu__divider"></div>
                <button class="menu__item menu__item--danger" type="button" @click="onLogout">
                  <AppIcon name="logout" :size="16" />
                  <span>退出登录</span>
                </button>
              </div>
            </Transition>
          </div>
        </template>

        <template v-else>
          <RouterLink to="/login" class="actions__login">登录</RouterLink>
          <AppButton size="sm" @click="router.push('/register')">免费开始</AppButton>
        </template>

        <button class="burger" type="button" :aria-expanded="menuOpen" aria-label="菜单" @click="menuOpen = !menuOpen">
          <AppIcon :name="menuOpen ? 'close' : 'menu'" :size="20" />
        </button>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { toast } from '../../utils/toast'
import AppButton from '../ui/AppButton.vue'
import AppIcon from '../ui/AppIcon.vue'
import ThemeToggle from '../ui/ThemeToggle.vue'

const NAV = [
  { to: '/', label: '首页' },
  { to: '/articles', label: '文章' },
  { to: '/ai', label: '树洞' },
  { to: '/assessment', label: '状态自查' },
  { to: '/diary', label: '情绪日记' },
]

const USER_MENU = [
  { to: '/me', label: '我的主页', icon: 'user' },
  { to: '/me/profile', label: '个人资料', icon: 'edit' },
  { to: '/me/records', label: '我的记录', icon: 'clipboard' },
  { to: '/settings', label: '设置', icon: 'settings' },
  { to: '/feedback', label: '意见反馈', icon: 'message' },
]

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

const scrolled = ref(false)
const menuOpen = ref(false)
const dropdownOpen = ref(false)
const userWrap = ref<HTMLElement | null>(null)

const initial = computed(() => (auth.displayName || '轻').slice(0, 1))

function isActive(to: string): boolean {
  if (to === '/') return route.path === '/'
  return route.path === to || route.path.startsWith(`${to}/`)
}

function onLogout(): void {
  dropdownOpen.value = false
  auth.logout()
  toast.info('已退出登录')
  router.push('/')
}

function onDocumentClick(ev: MouseEvent): void {
  if (!userWrap.value) return
  if (!userWrap.value.contains(ev.target as Node)) dropdownOpen.value = false
}

function onScroll(): void {
  scrolled.value = window.scrollY > 8
}

onMounted(() => {
  document.addEventListener('click', onDocumentClick)
  window.addEventListener('scroll', onScroll, { passive: true })
  onScroll()
})

onBeforeUnmount(() => {
  document.removeEventListener('click', onDocumentClick)
  window.removeEventListener('scroll', onScroll)
})
</script>

<style scoped>
.site-header {
  position: sticky;
  top: 0;
  z-index: 900;
  background: color-mix(in srgb, var(--bg) 82%, transparent);
  backdrop-filter: saturate(1.6) blur(16px);
  -webkit-backdrop-filter: saturate(1.6) blur(16px);
  border-bottom: 1px solid transparent;
  transition:
    border-color var(--motion-normal) var(--ease-standard),
    background-color var(--motion-normal) var(--ease-standard),
    box-shadow var(--motion-normal) var(--ease-standard);
}
.site-header--scrolled {
  border-bottom-color: var(--line);
  box-shadow: var(--shadow-sm);
}
.site-header__inner {
  display: flex;
  align-items: center;
  gap: var(--space-xl);
  height: var(--header-h);
}

.brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  flex: none;
}
.brand__mark {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border-radius: var(--radius-md);
  background: linear-gradient(150deg, var(--primary), var(--primary-pressed));
  color: var(--primary-contrast);
  box-shadow: var(--shadow-glow);
}
.brand__text {
  font-size: var(--font-2xl);
  font-weight: 700;
  letter-spacing: 0.02em;
  color: var(--text);
}

.nav {
  display: flex;
  align-items: center;
  gap: var(--space-xs);
  flex: 1;
}
.nav__link {
  position: relative;
  padding: 8px 14px;
  border-radius: var(--radius-full);
  font-size: var(--font-m);
  font-weight: 500;
  color: var(--text-2);
  transition:
    color var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard);
}
.nav__link:hover {
  color: var(--text);
  background: var(--card-soft);
}
.nav__link--active {
  color: var(--primary);
  background: var(--primary-weak);
  box-shadow: inset 0 0 0 1px var(--primary-border);
}

.actions {
  display: flex;
  align-items: center;
  gap: var(--space-s);
  flex: none;
}
.actions__login {
  padding: 0 12px;
  font-size: var(--font-m);
  font-weight: 600;
  color: var(--text-2);
  transition: color var(--motion-fast) var(--ease-standard);
}
.actions__login:hover {
  color: var(--primary);
}

.user {
  position: relative;
}
.user__trigger {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 40px;
  padding: 0 12px 0 4px;
  border: 1px solid var(--line);
  border-radius: var(--radius-full);
  background: var(--card);
  box-shadow: var(--shadow-sm);
  color: var(--text-2);
  transition:
    border-color var(--motion-fast) var(--ease-standard),
    box-shadow var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard);
}
.user__trigger:hover {
  border-color: var(--primary-border);
  box-shadow: var(--shadow-md);
  color: var(--text);
}
.user__avatar {
  width: 32px;
  height: 32px;
  border-radius: var(--radius-full);
  object-fit: cover;
  flex: none;
}
.user__avatar--fallback {
  display: grid;
  place-items: center;
  background: linear-gradient(150deg, var(--primary), var(--primary-pressed));
  color: var(--primary-contrast);
  font-size: var(--font-s);
  font-weight: 700;
  box-shadow: var(--shadow-glow);
}
.user__name {
  max-width: 96px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: var(--font-s);
  font-weight: 600;
  color: var(--text);
}

.menu {
  position: absolute;
  right: 0;
  top: calc(100% + 10px);
  min-width: 190px;
  padding: 6px;
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
}
.menu__item {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 9px 12px;
  border: none;
  border-radius: var(--radius-sm);
  background: transparent;
  color: var(--text-2);
  font-size: var(--font-m);
  text-align: left;
  transition:
    background-color var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard);
}
.menu__item:hover {
  background: var(--card-soft);
  color: var(--text);
}
.menu__item--danger {
  color: var(--danger);
}
.menu__item--danger:hover {
  background: color-mix(in srgb, var(--danger) 12%, transparent);
  color: var(--danger);
}
.menu__divider {
  height: 1px;
  margin: 6px 4px;
  background: var(--line);
}

.burger {
  display: none;
  place-items: center;
  width: 40px;
  height: 40px;
  border: 1px solid var(--line);
  border-radius: var(--radius-full);
  background: var(--card);
  box-shadow: var(--shadow-sm);
  color: var(--text-2);
}

.fade-up-enter-active,
.fade-up-leave-active {
  transition:
    opacity var(--motion-fast) var(--ease-standard),
    transform var(--motion-fast) var(--ease-emphasized);
}
.fade-up-enter-from,
.fade-up-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}

@media (max-width: 900px) {
  .nav {
    position: absolute;
    left: 0;
    right: 0;
    top: var(--header-h);
    flex-direction: column;
    align-items: stretch;
    gap: 2px;
    padding: var(--space-m);
    background: var(--card);
    border-bottom: 1px solid var(--line);
    box-shadow: var(--shadow-md);
    transform: translateY(-8px);
    opacity: 0;
    pointer-events: none;
    transition:
      opacity var(--motion-fast) var(--ease-standard),
      transform var(--motion-fast) var(--ease-emphasized);
  }
  .nav--open {
    transform: translateY(0);
    opacity: 1;
    pointer-events: auto;
  }
  .nav__link {
    padding: 12px 14px;
    border-radius: var(--radius-md);
  }
  .burger {
    display: grid;
  }
  .user__name {
    display: none;
  }
}
</style>
