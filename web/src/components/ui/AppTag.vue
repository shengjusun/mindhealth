<template>
  <span class="tag" :class="[`tag--${kind}`, `tag--${size}`]">
    <AppIcon v-if="icon" :name="icon" :size="size === 'lg' ? 15 : 13" />
    <slot />
  </span>
</template>

<script setup lang="ts">
import AppIcon from './AppIcon.vue'

withDefaults(
  defineProps<{
    kind?: 'primary' | 'success' | 'warning' | 'danger' | 'plain' | 'accent'
    size?: 'sm' | 'md' | 'lg'
    icon?: string
  }>(),
  { kind: 'plain', size: 'md' },
)
</script>

<style scoped>
.tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border-radius: var(--radius-full);
  font-weight: 600;
  line-height: 1;
  white-space: nowrap;
  border: 1px solid transparent;
}
.tag--sm {
  height: 22px;
  padding: 0 9px;
  font-size: var(--font-2xs);
}
.tag--md {
  height: 26px;
  padding: 0 11px;
  font-size: var(--font-xs);
}
.tag--lg {
  height: 30px;
  padding: 0 13px;
  font-size: var(--font-s);
}

.tag--plain {
  background: var(--card-soft);
  color: var(--text-2);
  border-color: var(--line);
}
.tag--primary {
  background: var(--primary-weak);
  color: var(--primary);
  border-color: var(--primary-border);
}
.tag--accent {
  background: var(--accent-weak);
  color: var(--accent);
}
.tag--success {
  background: color-mix(in srgb, var(--success) 12%, transparent);
  color: var(--success);
}
.tag--warning {
  background: color-mix(in srgb, var(--warning) 14%, transparent);
  color: var(--warning);
}
.tag--danger {
  background: color-mix(in srgb, var(--danger) 12%, transparent);
  color: var(--danger);
}
</style>
