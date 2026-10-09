// AI生成
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import SiteLayout from '../components/layout/SiteLayout.vue'
import AuthLayout from '../components/layout/AuthLayout.vue'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    component: SiteLayout,
    children: [
      { path: '', name: 'home', component: () => import('../views/HomeView.vue'), meta: { public: true, title: '首页' } },

      // 文章（公开）
      {
        path: 'articles',
        name: 'articles',
        component: () => import('../views/article/ArticleListView.vue'),
        meta: { public: true, title: '文章' },
      },
      {
        path: 'articles/:id',
        name: 'article-detail',
        component: () => import('../views/article/ArticleDetailView.vue'),
        meta: { public: true, title: '文章详情' },
      },

      // 树洞 AI
      { path: 'ai', name: 'ai', component: () => import('../views/ai/AiChatView.vue'), meta: { title: '树洞' } },

      // 情绪日记
      { path: 'diary', name: 'diary', component: () => import('../views/diary/DiaryListView.vue'), meta: { title: '情绪日记' } },
      {
        path: 'diary/new',
        name: 'diary-new',
        component: () => import('../views/diary/DiaryEditView.vue'),
        meta: { title: '写日记' },
      },
      {
        path: 'diary/:id',
        name: 'diary-detail',
        component: () => import('../views/diary/DiaryDetailView.vue'),
        meta: { title: '日记详情' },
      },
      {
        path: 'diary/:id/edit',
        name: 'diary-edit',
        component: () => import('../views/diary/DiaryEditView.vue'),
        meta: { title: '编辑日记' },
      },

      // 状态自查
      {
        path: 'assessment',
        name: 'assessment',
        component: () => import('../views/assessment/AssessmentListView.vue'),
        meta: { title: '状态自查' },
      },
      {
        path: 'assessment/result/:id',
        name: 'assessment-result',
        component: () => import('../views/assessment/AssessmentResultView.vue'),
        meta: { title: '测评报告' },
      },
      {
        path: 'assessment/:id',
        name: 'assessment-paper',
        component: () => import('../views/assessment/AssessmentPaperView.vue'),
        meta: { title: '开始测评' },
      },

      // 我的
      { path: 'me', name: 'me', component: () => import('../views/me/MeView.vue'), meta: { title: '我的' } },
      {
        path: 'me/profile',
        name: 'profile',
        component: () => import('../views/me/ProfileEditView.vue'),
        meta: { title: '个人资料' },
      },
      {
        path: 'me/records',
        name: 'records',
        component: () => import('../views/me/MyRecordsView.vue'),
        meta: { title: '我的记录' },
      },
      {
        path: 'settings',
        name: 'settings',
        component: () => import('../views/me/SettingsView.vue'),
        meta: { title: '设置' },
      },
      {
        path: 'feedback',
        name: 'feedback',
        component: () => import('../views/me/FeedbackView.vue'),
        meta: { title: '意见反馈' },
      },

      { path: ':pathMatch(.*)*', name: 'not-found', component: () => import('../views/NotFoundView.vue'), meta: { public: true, title: '页面不存在' } },
    ],
  },
  {
    path: '/login',
    component: AuthLayout,
    children: [{ path: '', name: 'login', component: () => import('../views/auth/LoginView.vue'), meta: { public: true, title: '登录' } }],
  },
  {
    path: '/register',
    component: AuthLayout,
    children: [
      { path: '', name: 'register', component: () => import('../views/auth/RegisterView.vue'), meta: { public: true, title: '注册' } },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(_to, _from, savedPosition) {
    return savedPosition ?? { top: 0 }
  },
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  const isPublic = to.meta.public === true
  if (!isPublic && !auth.isLoggedIn) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
  if (auth.isLoggedIn && (to.name === 'login' || to.name === 'register')) {
    return { path: '/' }
  }
  return true
})

router.afterEach((to) => {
  const title = typeof to.meta.title === 'string' ? to.meta.title : ''
  document.title = title ? `${title} · 轻心` : '轻心 · 你的情绪陪伴'
})

export default router
