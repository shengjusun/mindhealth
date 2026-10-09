// AI生成
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useThemeStore } from './stores/theme'
import { vReveal } from './composables/useReveal'
import { vTilt, vParallax } from './composables/useMotion'
import './styles/tokens.css'
import './styles/base.css'
import './styles/motion.css'

const app = createApp(App)
app.use(createPinia())
app.use(router)

// 滚动揭示：v-reveal（全站共用一个 IntersectionObserver）
app.directive('reveal', vReveal)
// 轻动效：卡片 3D 倾斜 / 滚动视差（reduced-motion 下自动不注册）
app.directive('tilt', vTilt)
app.directive('parallax', vParallax)

// 主题：应用一次并监听系统深浅色变化（auto 模式下自动跟随）
const theme = useThemeStore()
theme.apply()
theme.watchSystem()

app.mount('#app')
