<template>
  <label class="field">
    <span v-if="label" class="field__label">{{ label }}</span>
    <span class="field__box" :class="{ 'field__box--error': !!error, 'field__box--focus': focused }">
      <AppIcon v-if="icon" :name="icon" :size="17" class="field__icon" />
      <input
        class="field__input"
        :type="actualType"
        :value="modelValue"
        :placeholder="placeholder"
        :autocomplete="autocomplete"
        :maxlength="maxlength"
        :disabled="disabled"
        @input="onInput"
        @focus="focused = true"
        @blur="focused = false"
      />
      <span v-if="$slots.suffix" class="field__suffix"><slot name="suffix" /></span>
    </span>
    <span v-if="error" class="field__msg field__msg--error">{{ error }}</span>
    <span v-else-if="hint" class="field__msg">{{ hint }}</span>
  </label>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import AppIcon from './AppIcon.vue'

const props = withDefaults(
  defineProps<{
    modelValue: string
    label?: string
    placeholder?: string
    type?: 'text' | 'password' | 'tel' | 'number' | 'email'
    icon?: string
    /** 视觉类型，实际 type（如 password 的明文切换）由 reveal 控制 */
    error?: string
    hint?: string
    maxlength?: number
    autocomplete?: string
    disabled?: boolean
  }>(),
  { type: 'text', placeholder: '', icon: '', error: '', hint: '', disabled: false },
)

const emit = defineEmits<{ (e: 'update:modelValue', value: string): void }>()

const focused = ref(false)
const actualType = computed(() => props.type)

function onInput(ev: Event): void {
  emit('update:modelValue', (ev.target as HTMLInputElement).value)
}
</script>

<style scoped>
.field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.field__label {
  font-size: var(--font-s);
  font-weight: 600;
  color: var(--text-2);
}
.field__box {
  display: flex;
  align-items: center;
  gap: var(--space-s);
  height: 46px;
  padding: 0 var(--space-l);
  background: var(--card);
  border: 1px solid var(--line-strong);
  border-radius: var(--radius-md);
  transition:
    border-color var(--motion-fast) var(--ease-standard),
    box-shadow var(--motion-fast) var(--ease-standard),
    background-color var(--motion-fast) var(--ease-standard);
}
.field__box--focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px var(--primary-weak);
}
.field__box--error {
  border-color: var(--danger);
}
.field__icon {
  color: var(--text-3);
}
.field__box--focus .field__icon {
  color: var(--primary);
}
.field__input {
  flex: 1;
  min-width: 0;
  border: none;
  outline: none;
  background: transparent;
  font-size: var(--font-m);
  color: var(--text);
}
.field__input::placeholder {
  color: var(--text-3);
}
.field__suffix {
  display: inline-flex;
  align-items: center;
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
