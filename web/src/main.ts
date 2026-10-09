// AI生成
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useThemeStore } from './stores/theme'
import './styles/tokens.css'
import './styles/base.css'

const app = createApp(App)
app.use(createPinia())
app.use(router)

// 主题：应用一次并监听系统深浅色变化（auto 模式下自动跟随）
const theme = useThemeStore()
theme.apply()
theme.watchSystem()

app.mount('#app')
