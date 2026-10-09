<template>
  <footer class="site-footer">
    <div class="container site-footer__inner">
      <div class="site-footer__brand">
        <div class="brand">
          <span class="brand__mark"><AppIcon name="leaf" :size="18" /></span>
          <span class="brand__text">轻心</span>
        </div>
        <p class="site-footer__slogan">一处安放心情的地方，慢一点也没关系。</p>
      </div>

      <div class="site-footer__cols">
        <div class="col">
          <h4 class="col__title">探索</h4>
          <RouterLink to="/articles" class="col__link">文章</RouterLink>
          <RouterLink to="/assessment" class="col__link">状态自查</RouterLink>
          <RouterLink to="/ai" class="col__link">树洞陪伴</RouterLink>
        </div>
        <div class="col">
          <h4 class="col__title">记录</h4>
          <RouterLink to="/diary" class="col__link">情绪日记</RouterLink>
          <RouterLink to="/me/records" class="col__link">我的记录</RouterLink>
          <RouterLink to="/me" class="col__link">我的主页</RouterLink>
        </div>
        <div class="col">
          <h4 class="col__title">帮助</h4>
          <RouterLink to="/feedback" class="col__link">意见反馈</RouterLink>
          <RouterLink to="/settings" class="col__link">设置</RouterLink>
        </div>
      </div>
    </div>

    <div class="container site-footer__bottom">
      <p class="site-footer__note">
        轻心不提供医疗诊断与治疗建议。若你正处在强烈的痛苦中，请及时联系专业机构或拨打心理援助热线 12356。
      </p>
      <p class="site-footer__copy">© {{ year }} 轻心 · 用温柔的方式，陪你看见自己</p>
    </div>
  </footer>
</template>

<script setup lang="ts">
import { RouterLink } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'

const year = new Date().getFullYear()
</script>

<style scoped>
.site-footer {
  margin-top: var(--space-4xl);
  padding-top: var(--space-4xl);
  border-top: 1px solid var(--line);
  background: var(--bg-soft);
}
.site-footer__inner {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-4xl);
  justify-content: space-between;
  padding-bottom: var(--space-3xl);
}
.site-footer__brand {
  max-width: 320px;
}
.brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
}
.brand__mark {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-sm);
  background: var(--primary-weak);
  color: var(--primary);
}
.brand__text {
  font-size: var(--font-2xl);
  font-weight: 700;
  color: var(--text);
}
.site-footer__slogan {
  margin-top: var(--space-m);
  font-size: var(--font-s);
  line-height: 1.8;
  color: var(--text-3);
}

.site-footer__cols {
  display: flex;
  gap: var(--space-4xl);
  flex-wrap: wrap;
}
.col {
  display: flex;
  flex-direction: column;
  gap: 10px;
  min-width: 108px;
}
.col__title {
  margin: 0 0 2px;
  font-size: var(--font-s);
  font-weight: 700;
  color: var(--text);
}
.col__link {
  font-size: var(--font-s);
  color: var(--text-3);
  transition: color var(--motion-fast) var(--ease-standard);
}
.col__link:hover {
  color: var(--primary);
}

.site-footer__bottom {
  display: flex;
  flex-direction: column;
  gap: var(--space-s);
  padding: var(--space-l) 0 var(--space-2xl);
  border-top: 1px solid var(--line);
}
.site-footer__note {
  font-size: var(--font-xs);
  line-height: 1.8;
  color: var(--text-3);
}
.site-footer__copy {
  font-size: var(--font-xs);
  color: var(--text-3);
}

@media (max-width: 640px) {
  .site-footer__inner {
    gap: var(--space-2xl);
  }
  .site-footer__cols {
    gap: var(--space-2xl);
  }
}
</style>
