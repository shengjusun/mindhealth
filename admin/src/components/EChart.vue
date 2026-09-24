<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import echarts from '../utils/echarts'
import type { ECharts, EChartsCoreOption } from 'echarts/core'

const props = withDefaults(
  defineProps<{
    option: EChartsCoreOption
    height?: string
  }>(),
  { height: '260px' },
)

const root = ref<HTMLDivElement | null>(null)
const chart = shallowRef<ECharts | null>(null)
let observer: ResizeObserver | null = null

function render(): void {
  if (!chart.value) return
  chart.value.setOption(props.option, true)
}

onMounted(() => {
  if (!root.value) return
  chart.value = echarts.init(root.value, undefined, { renderer: 'canvas' })
  render()
  observer = new ResizeObserver(() => {
    chart.value?.resize()
  })
  observer.observe(root.value)
})

watch(
  () => props.option,
  () => render(),
  { deep: true },
)

onBeforeUnmount(() => {
  observer?.disconnect()
  observer = null
  chart.value?.dispose()
  chart.value = null
})
</script>

<template>
  <div ref="root" class="chart" :style="{ height: props.height }" />
</template>

<style scoped>
.chart {
  width: 100%;
}
</style>
