<template>
  <div class="skeleton" :class="{ 'skeleton--card': variant === 'card' }">
    <template v-if="variant === 'card'">
      <div class="sk sk--title" />
      <div class="sk sk--line" />
      <div class="sk sk--line" style="width: 70%" />
    </template>
    <template v-else>
      <div v-for="n in lines" :key="n" class="sk sk--line" :style="{ width: widths[n - 1] }" />
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{ variant?: 'text' | 'card'; lines?: number }>(), {
  variant: 'text',
  lines: 3,
})

const widths = computed(() => Array.from({ length: props.lines }, (_, i) => (i === props.lines - 1 ? '62%' : '100%')))
</script>

<style scoped>
.skeleton {
  display: flex;
  flex-direction: column;
  gap: var(--space-m);
}
.skeleton--card {
  padding: var(--space-xl);
  border: 1px solid var(--line);
  border-radius: var(--radius-lg);
  background: var(--card);
}
.sk {
  border-radius: var(--radius-sm);
  background: linear-gradient(90deg, var(--card-soft) 25%, var(--line) 37%, var(--card-soft) 63%);
  background-size: 400% 100%;
  animation: shimmer 1.4s ease infinite;
}
.sk--title {
  height: 22px;
  width: 42%;
}
.sk--line {
  height: 14px;
  width: 100%;
}
@keyframes shimmer {
  0% {
    background-position: 100% 0;
  }
  100% {
    background-position: 0 0;
  }
}
</style>
