<template>
  <Teleport to="body">
    <div class="toast-host" aria-live="polite">
      <TransitionGroup name="toast">
        <div v-for="item in toasts" :key="item.id" class="toast" :class="`toast--${item.kind}`" @click="dismissToast(item.id)">
          <AppIcon :name="iconOf(item.kind)" :size="16" />
          <span class="toast__text">{{ item.message }}</span>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { toasts, dismissToast, type ToastKind } from '../../utils/toast'
import AppIcon from './AppIcon.vue'

function iconOf(kind: ToastKind): string {
  if (kind === 'success') return 'check'
  if (kind === 'error') return 'alert'
  if (kind === 'warning') return 'alert'
  return 'info'
}
</script>

<style scoped>
.toast-host {
  position: fixed;
  top: 84px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 2000;
  display: flex;
  flex-direction: column;
  gap: var(--space-s);
  align-items: center;
  pointer-events: none;
}
.toast {
  pointer-events: auto;
  display: flex;
  align-items: center;
  gap: var(--space-s);
  max-width: min(88vw, 420px);
  padding: 10px 16px;
  border-radius: var(--radius-full);
  background: var(--card);
  color: var(--text);
  border: 1px solid var(--line-strong);
  box-shadow: var(--shadow-md);
  font-size: var(--font-m);
  cursor: pointer;
}
.toast--success {
  color: var(--success);
}
.toast--error {
  color: var(--danger);
}
.toast--warning {
  color: var(--warning);
}
.toast--info {
  color: var(--text);
}
.toast__text {
  color: var(--text);
}

.toast-enter-active,
.toast-leave-active {
  transition:
    opacity var(--motion-normal) var(--ease-emphasized),
    transform var(--motion-normal) var(--ease-emphasized);
}
.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(-10px) scale(0.98);
}
</style>
