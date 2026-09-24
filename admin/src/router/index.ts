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
        component: () => import('../views/DiaryList.vue'),
        meta: { title: '日记管理' },
      },
      {
        path: 'assessments',
        name: 'assessments',
        component: () => import('../views/Assessment.vue'),
        meta: { title: '测评题库' },
      },
      {
        path: 'feedback',
        name: 'feedback',
        component: () => import('../views/Feedback.vue'),
        meta: { title: '用户反馈' },
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
