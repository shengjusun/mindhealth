<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="modelValue" class="modal-mask" @click.self="onMaskClick">
        <div class="modal" :style="{ width: widthValue }" role="dialog" aria-modal="true">
          <header class="modal__head">
            <h3 class="modal__title">{{ title }}</h3>
            <button class="modal__close" type="button" aria-label="关闭" @click="close">
              <AppIcon name="close" :size="18" />
            </button>
          </header>
          <div class="modal__body">
            <slot />
          </div>
          <footer v-if="$slots.footer" class="modal__foot">
            <slot name="footer" />
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import AppIcon from './AppIcon.vue'

const props = withDefaults(
  defineProps<{
    modelValue: boolean
    title?: string
    width?: number | string
    closeOnOverlay?: boolean
  }>(),
  { title: '', width: 440, closeOnOverlay: true },
)

const emit = defineEmits<{ (e: 'update:modelValue', value: boolean): void }>()

const widthValue = computed(() => (typeof props.width === 'number' ? `${props.width}px` : props.width))

function close(): void {
  emit('update:modelValue', false)
}
function onMaskClick(): void {
  if (props.closeOnOverlay) close()
}
</script>

<style scoped>
.modal-mask {
  position: fixed;
  inset: 0;
  z-index: 1500;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-xl);
  background: var(--overlay);
  backdrop-filter: blur(2px);
}
.modal {
  max-width: 100%;
  max-height: 88vh;
  overflow: auto;
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: var(--radius-xl);
  box-shadow: var(--shadow-lg);
  padding: var(--space-2xl);
}
.modal__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-l);
  margin-bottom: var(--space-l);
}
.modal__title {
  font-size: var(--font-2xl);
}
.modal__close {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border: none;
  border-radius: var(--radius-full);
  background: transparent;
  color: var(--text-3);
  transition: background-color var(--motion-fast) var(--ease-standard);
}
.modal__close:hover {
  background: var(--card-soft);
  color: var(--text);
}
.modal__body {
  color: var(--text-2);
  font-size: var(--font-m);
}
.modal__foot {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-m);
  margin-top: var(--space-2xl);
}

.modal-enter-active,
.modal-leave-active {
  transition: opacity var(--motion-normal) var(--ease-standard);
}
.modal-enter-active .modal,
.modal-leave-active .modal {
  transition:
    transform var(--motion-normal) var(--ease-emphasized),
    opacity var(--motion-normal) var(--ease-standard);
}
.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}
.modal-enter-from .modal,
.modal-leave-to .modal {
  transform: translateY(10px) scale(0.98);
  opacity: 0;
}
</style>
