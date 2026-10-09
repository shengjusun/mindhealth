<template>
  <span class="spinner" :style="{ width: `${size}px`, height: `${size}px`, borderWidth: `${Math.max(2, Math.round(size / 9))}px` }" />
</template>

<script setup lang="ts">
withDefaults(defineProps<{ size?: number }>(), { size: 18 })
</script>

<style scoped>
.spinner {
  display: inline-block;
  border-style: solid;
  border-color: currentColor;
  border-top-color: transparent;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
