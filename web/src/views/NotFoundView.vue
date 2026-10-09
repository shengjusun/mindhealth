<template>
  <div class="nf">
    <div class="nf__card">
      <span class="nf__code">404</span>
      <h1 class="nf__title">这里好像静悄悄的</h1>
      <p class="nf__desc">你要找的页面走丢了，不如先回到开始的地方，慢慢来。</p>
      <div class="nf__actions">
        <AppButton size="lg" icon="home" @click="router.replace('/')">回到首页</AppButton>
        <AppButton size="lg" kind="secondary" icon="arrow-left" @click="router.back()">返回上一页</AppButton>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import AppButton from '../components/ui/AppButton.vue'

const router = useRouter()
</script>

<style scoped>
.nf {
  display: grid;
  place-items: center;
  min-height: 62vh;
  padding: var(--space-4xl) var(--space-xl);
}
.nf__card {
  max-width: 520px;
  padding: var(--space-3xl) var(--space-2xl);
  text-align: center;
  border-radius: var(--radius-2xl);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm), inset 0 1px 0 var(--glass-sheen);
}
.nf__code {
  display: inline-block;
  font-size: 72px;
  font-weight: 800;
  line-height: 1;
  letter-spacing: 0.04em;
  background: linear-gradient(120deg, var(--primary), var(--accent));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}
.nf__title {
  margin-top: var(--space-l);
  font-size: var(--font-page-title);
}
.nf__desc {
  margin-top: var(--space-m);
  font-size: var(--font-l);
  line-height: 1.9;
  color: var(--text-2);
}
.nf__actions {
  display: flex;
  justify-content: center;
  gap: var(--space-m);
  margin-top: var(--space-3xl);
  flex-wrap: wrap;
}
</style>
