import { createRouter, createWebHistory } from 'vue-router'
import { isLoggedIn } from '../auth'
import AdminLayout from '../layout/AdminLayout.vue'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/Login.vue'),
    meta: { public: true },
  },
  {
    path: '/',
    component: AdminLayout,
    children: [
      { path: '', redirect: '/dashboard' },
      {
        path: 'dashboard',
        name: 'dashboard',
        component: () => import('../views/Dashboard.vue'),
        meta: { title: '数据概览' },
      },
      {
        path: 'users',
        name: 'users',
        component: () => import('../views/UserList.vue'),
        meta: { title: '用户管理' },
      },
      {
        path: 'diaries',
        name: 'diaries',
        component: () => import('../views/diary/DiaryUserList.vue'),
        meta: { title: '日记管理' },
      },
      {
        /**
         * 二级页：单个用户的日记。
         * 日记是高敏感私密内容，一级页只列用户，必须点进具体的人才能看到内容，
         * 避免所有人最私密的文本平铺在一张表上。
         */
        path: 'diaries/user/:userId',
        name: 'diary-user',
        component: () => import('../views/diary/DiaryUserDetail.vue'),
        meta: {
          title: '用户日记',
          // 让侧边栏在这一层仍高亮「日记管理」
          activeMenu: '/diaries',
          // 面包屑回跳用
          parent: { title: '日记管理', path: '/diaries' },
        },
      },
      {
        path: 'assessments',
        name: 'assessments',
        component: () => import('../views/Assessment.vue'),
        meta: { title: '测评题库' },
      },
      {
        path: 'assessment-results',
        name: 'assessment-results',
        component: () => import('../views/AssessmentResults.vue'),
        meta: { title: '测评结果' },
      },
      {
        path: 'feedback',
        name: 'feedback',
        component: () => import('../views/Feedback.vue'),
        meta: { title: '用户反馈' },
      },
      {
        path: 'logs',
        name: 'logs',
        component: () => import('../views/OperationLog.vue'),
        meta: { title: '操作日志' },
      },
      {
        path: 'accounts',
        name: 'accounts',
        component: () => import('../views/AdminAccounts.vue'),
        meta: { title: '管理员账号' },
      },
      {
        path: 'profile',
        name: 'profile',
        component: () => import('../views/Profile.vue'),
        meta: { title: '个人资料' },
      },
    ],
  },
  { path: '/:pathMatch(.*)*', redirect: '/dashboard' },
]

export const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

router.beforeEach((to) => {
  if (!to.meta.public && !isLoggedIn()) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
  if (to.path === '/login' && isLoggedIn()) {
    return '/dashboard'
  }
  return true
})
