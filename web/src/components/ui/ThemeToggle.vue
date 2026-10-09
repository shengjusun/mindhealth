<template>
  <button class="theme-toggle" type="button" :title="title" @click="store.toggle()">
    <AppIcon :name="store.isDark ? 'moon' : 'sun'" :size="18" />
  </button>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useThemeStore } from '../../stores/theme'
import AppIcon from './AppIcon.vue'

const store = useThemeStore()
const title = computed(() => (store.isDark ? '切换到浅色' : '切换到深色'))
</script>

<style scoped>
.theme-toggle {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border: 1px solid var(--line);
  border-radius: var(--radius-full);
  background: var(--card);
  color: var(--text-2);
  transition:
    color var(--motion-fast) var(--ease-standard),
    border-color var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard),
    transform var(--motion-fast) var(--ease-standard);
}
.theme-toggle:hover {
  color: var(--primary);
  border-color: var(--primary-border);
  background: var(--primary-weak);
}
.theme-toggle:active {
  transform: scale(0.94);
}
</style>
