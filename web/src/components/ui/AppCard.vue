<template>
  <div class="card" :class="[`card--${padding}`, { 'card--hover': hoverable, 'card--flat': flat }]">
    <header v-if="title || $slots.header" class="card__head">
      <slot name="header">
        <div class="card__titles">
          <h3 class="card__title">{{ title }}</h3>
          <p v-if="subtitle" class="card__subtitle">{{ subtitle }}</p>
        </div>
      </slot>
      <div v-if="$slots.action" class="card__action"><slot name="action" /></div>
    </header>
    <slot />
    <footer v-if="$slots.footer" class="card__foot"><slot name="footer" /></footer>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    title?: string
    subtitle?: string
    padding?: 'none' | 'sm' | 'md' | 'lg'
    hoverable?: boolean
    flat?: boolean
  }>(),
  { padding: 'md', hoverable: false, flat: false },
)
</script>

<style scoped>
.card {
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
  transition:
    transform var(--motion-normal) var(--ease-emphasized),
    box-shadow var(--motion-normal) var(--ease-emphasized),
    border-color var(--motion-normal) var(--ease-emphasized),
    background-color var(--motion-normal) var(--ease-standard);
}
.card--flat {
  box-shadow: none;
}
.card--none {
  padding: 0;
}
.card--sm {
  padding: var(--space-l);
}
.card--md {
  padding: var(--space-xl);
}
.card--lg {
  padding: var(--space-2xl);
}
.card--hover {
  cursor: pointer;
}
.card--hover:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-md);
  border-color: var(--primary-border);
}

.card__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--space-l);
  margin-bottom: var(--space-l);
}
.card__title {
  font-size: var(--font-2xl);
  font-weight: 700;
}
.card__subtitle {
  margin-top: 4px;
  color: var(--text-2);
  font-size: var(--font-s);
}
.card__action {
  flex: none;
}
.card__foot {
  margin-top: var(--space-l);
  padding-top: var(--space-l);
  border-top: 1px solid var(--line);
}
</style>
