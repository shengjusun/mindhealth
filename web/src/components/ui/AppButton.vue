<template>
  <button
    class="btn"
    :class="[`btn--${kind}`, `btn--${size}`, { 'btn--block': block, 'btn--loading': loading }]"
    :type="nativeType"
    :disabled="disabled || loading"
    @click="onClick"
  >
    <AppSpinner v-if="loading" :size="size === 'lg' ? 18 : 16" />
    <AppIcon v-else-if="icon" :name="icon" :size="size === 'lg' ? 18 : 16" />
    <span class="btn__label"><slot /></span>
  </button>
</template>

<script setup lang="ts">
import AppIcon from './AppIcon.vue'
import AppSpinner from './AppSpinner.vue'

withDefaults(
  defineProps<{
    kind?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'text'
    size?: 'sm' | 'md' | 'lg'
    icon?: string
    block?: boolean
    loading?: boolean
    disabled?: boolean
    nativeType?: 'button' | 'submit' | 'reset'
  }>(),
  { kind: 'primary', size: 'md', block: false, loading: false, disabled: false, nativeType: 'button' },
)

const emit = defineEmits<{ (e: 'click', ev: MouseEvent): void }>()

function onClick(ev: MouseEvent): void {
  emit('click', ev)
}
</script>

<style scoped>
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-s);
  border: 1px solid transparent;
  border-radius: var(--radius-md);
  font-weight: 600;
  line-height: 1;
  white-space: nowrap;
  transition:
    transform var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard),
    border-color var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard),
    box-shadow var(--motion-fast) var(--ease-standard),
    opacity var(--motion-fast) var(--ease-standard);
}
.btn:active:not(:disabled) {
  transform: scale(0.97);
}
.btn:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

/* 尺寸 */
.btn--sm {
  height: 34px;
  padding: 0 14px;
  font-size: var(--font-s);
}
.btn--md {
  height: 44px;
  padding: 0 20px;
  font-size: var(--font-m);
}
.btn--lg {
  height: 50px;
  padding: 0 26px;
  font-size: var(--font-l);
}
.btn--block {
  display: flex;
  width: 100%;
}

/* 变体 */
.btn--primary {
  background: var(--primary);
  color: var(--primary-contrast);
  box-shadow: 0 6px 16px var(--primary-weak2);
}
.btn--primary:hover:not(:disabled) {
  background: var(--primary-pressed);
}

.btn--secondary {
  background: var(--card);
  color: var(--text);
  border-color: var(--line-strong);
}
.btn--secondary:hover:not(:disabled) {
  border-color: var(--primary-border);
  color: var(--primary);
  background: var(--primary-weak);
}

.btn--ghost {
  background: var(--primary-weak);
  color: var(--primary);
}
.btn--ghost:hover:not(:disabled) {
  background: var(--primary-weak2);
}

.btn--danger {
  background: transparent;
  color: var(--danger);
  border-color: color-mix(in srgb, var(--danger) 40%, transparent);
}
.btn--danger:hover:not(:disabled) {
  background: color-mix(in srgb, var(--danger) 12%, transparent);
}

.btn--text {
  background: transparent;
  color: var(--primary);
  padding: 0 6px;
  height: auto;
}
.btn--text:hover:not(:disabled) {
  text-decoration: underline;
}

.btn__label {
  display: inline-flex;
  align-items: center;
}
</style>
