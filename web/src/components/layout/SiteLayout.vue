<template>
  <div class="site">
    <SiteHeader />
    <main class="site__main">
      <RouterView v-slot="{ Component, route }">
        <Transition name="page" mode="out-in">
          <component :is="Component" :key="route.path" />
        </Transition>
      </RouterView>
    </main>
    <SiteFooter />
  </div>
</template>

<script setup lang="ts">
import { RouterView } from 'vue-router'
import SiteFooter from './SiteFooter.vue'
import SiteHeader from './SiteHeader.vue'
</script>

<style scoped>
.site {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  background: var(--bg);
}
.site__main {
  flex: 1;
}

.page-enter-active,
.page-leave-active {
  transition:
    opacity var(--motion-normal) var(--ease-standard),
    transform var(--motion-normal) var(--ease-emphasized);
}
.page-enter-from {
  opacity: 0;
  transform: translateY(8px);
}
.page-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
</style>
