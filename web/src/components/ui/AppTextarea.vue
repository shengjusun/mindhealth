<template>
  <label class="field">
    <span v-if="label" class="field__label">
      {{ label }}
      <span v-if="showCount" class="field__count">{{ modelValue.length }}<template v-if="maxlength">/{{ maxlength }}</template></span>
    </span>
    <span class="field__box" :class="{ 'field__box--error': !!error, 'field__box--focus': focused }">
      <textarea
        class="field__area"
        :value="modelValue"
        :placeholder="placeholder"
        :rows="rows"
        :maxlength="maxlength"
        :disabled="disabled"
        @input="onInput"
        @focus="focused = true"
        @blur="focused = false"
      />
    </span>
    <span v-if="error" class="field__msg field__msg--error">{{ error }}</span>
    <span v-else-if="hint" class="field__msg">{{ hint }}</span>
  </label>
</template>

<script setup lang="ts">
import { ref } from 'vue'

withDefaults(
  defineProps<{
    modelValue: string
    label?: string
    placeholder?: string
    rows?: number
    maxlength?: number
    error?: string
    hint?: string
    showCount?: boolean
    disabled?: boolean
  }>(),
  { label: '', placeholder: '', rows: 5, maxlength: undefined, error: '', hint: '', showCount: false, disabled: false },
)

const emit = defineEmits<{ (e: 'update:modelValue', value: string): void }>()
const focused = ref(false)

function onInput(ev: Event): void {
  emit('update:modelValue', (ev.target as HTMLTextAreaElement).value)
}
</script>

<style scoped>
.field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.field__label {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: var(--font-s);
  font-weight: 600;
  color: var(--text-2);
}
.field__count {
  font-weight: 400;
  color: var(--text-3);
}
.field__box {
  padding: var(--space-m) var(--space-l);
  background: var(--card);
  border: 1px solid var(--line-strong);
  border-radius: var(--radius-md);
  transition:
    border-color var(--motion-fast) var(--ease-standard),
    box-shadow var(--motion-fast) var(--ease-standard);
}
.field__box--focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px var(--primary-weak);
}
.field__box--error {
  border-color: var(--danger);
}
.field__area {
  width: 100%;
  border: none;
  outline: none;
  resize: vertical;
  background: transparent;
  font-size: var(--font-m);
  line-height: 1.7;
  color: var(--text);
}
.field__area::placeholder {
  color: var(--text-3);
}
.field__msg {
  font-size: var(--font-xs);
  color: var(--text-3);
}
.field__msg--error {
  color: var(--danger);
}
</style>
