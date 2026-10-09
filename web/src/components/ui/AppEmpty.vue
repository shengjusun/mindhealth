<template>
  <div class="empty">
    <div class="empty__icon">
      <AppIcon :name="icon" :size="30" />
    </div>
    <p class="empty__title">{{ title }}</p>
    <p v-if="description" class="empty__desc">{{ description }}</p>
    <div v-if="$slots.action" class="empty__action"><slot name="action" /></div>
  </div>
</template>

<script setup lang="ts">
import AppIcon from './AppIcon.vue'

withDefaults(defineProps<{ icon?: string; title?: string; description?: string }>(), {
  icon: 'wind',
  title: '这里还什么都没有',
  description: '',
})
</script>

<style scoped>
.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: var(--space-4xl) var(--space-xl);
}
.empty__icon {
  display: grid;
  place-items: center;
  width: 64px;
  height: 64px;
  border-radius: var(--radius-full);
  background: var(--primary-weak);
  color: var(--primary);
  margin-bottom: var(--space-l);
}
.empty__title {
  font-size: var(--font-xl);
  font-weight: 600;
  color: var(--text);
}
.empty__desc {
  margin-top: 6px;
  max-width: 32ch;
  color: var(--text-3);
  font-size: var(--font-s);
}
.empty__action {
  margin-top: var(--space-xl);
}
</style>
