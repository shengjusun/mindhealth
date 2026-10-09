<template>
  <div class="auth">
    <div class="auth__aside">
      <RouterLink to="/" class="auth__brand">
        <span class="brand__mark"><AppIcon name="leaf" :size="20" /></span>
        <span class="brand__text">轻心</span>
      </RouterLink>

      <div class="auth__copy">
        <h2 class="auth__title">慢一点，也没关系</h2>
        <p class="auth__desc">
          记录情绪、了解自己、和树洞聊聊天。<br />
          这里没有评判，只有陪你一起看见心情的眼睛。
        </p>
      </div>

      <ul class="auth__points">
        <li v-for="p in POINTS" :key="p.text" class="point">
          <span class="point__icon"><AppIcon :name="p.icon" :size="16" /></span>
          <span>{{ p.text }}</span>
        </li>
      </ul>
    </div>

    <div class="auth__main">
      <div class="auth__top">
        <ThemeToggle />
      </div>
      <div class="auth__panel">
        <RouterView v-slot="{ Component, route }">
          <Transition name="fade-up" mode="out-in">
            <component :is="Component" :key="route.path" />
          </Transition>
        </RouterView>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { RouterLink, RouterView } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import ThemeToggle from '../ui/ThemeToggle.vue'

const POINTS = [
  { icon: 'book-open', text: '精选文章，随时翻一翻' },
  { icon: 'message', text: '树洞随时在，想说什么都可以' },
  { icon: 'clipboard', text: '温和的自查，帮你看清状态' },
  { icon: 'shield', text: '你的记录只属于你自己' },
]
</script>

<style scoped>
.auth {
  display: grid;
  grid-template-columns: 1.05fr 1fr;
  min-height: 100vh;
  background: var(--bg);
}

.auth__aside {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: var(--space-3xl);
  padding: var(--space-4xl) 8%;
  background: var(--bg);
  border-right: 1px solid var(--line);
}
.auth__brand {
  position: absolute;
  top: var(--space-3xl);
  left: 8%;
  display: inline-flex;
  align-items: center;
  gap: 10px;
}
.brand__mark {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border-radius: var(--radius-sm);
  background: var(--primary-weak);
  color: var(--primary);
}
.brand__text {
  font-size: var(--font-2xl);
  font-weight: 700;
  color: var(--text);
}

.auth__copy {
  max-width: 420px;
}
.auth__title {
  font-size: clamp(26px, 3vw, 36px);
  line-height: 1.35;
}
.auth__desc {
  margin-top: var(--space-l);
  font-size: var(--font-l);
  line-height: 2;
  color: var(--text-2);
}

.auth__points {
  display: flex;
  flex-direction: column;
  gap: var(--space-m);
  list-style: none;
  padding: 0;
  margin: 0;
}
.point {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: var(--font-s);
  color: var(--text-2);
}
.point__icon {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: var(--radius-full);
  background: var(--card);
  color: var(--primary);
  border: 1px solid var(--line);
}

.auth__main {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-4xl) var(--space-xl);
}
.auth__top {
  position: absolute;
  top: var(--space-2xl);
  right: var(--space-2xl);
}
.auth__panel {
  width: 100%;
  max-width: 400px;
}

.fade-up-enter-active,
.fade-up-leave-active {
  transition:
    opacity var(--motion-normal) var(--ease-standard),
    transform var(--motion-normal) var(--ease-emphasized);
}
.fade-up-enter-from {
  opacity: 0;
  transform: translateY(10px);
}
.fade-up-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}

@media (max-width: 900px) {
  .auth {
    grid-template-columns: 1fr;
  }
  .auth__aside {
    display: none;
  }
  .auth__main {
    min-height: 100vh;
  }
}
</style>
