<template>
  <div class="chat">
    <div class="container chat__inner">
      <header class="chat__head">
        <div class="chat__brand">
          <span class="chat__avatar"><AppIcon name="leaf" :size="20" /></span>
          <div>
            <h1 class="chat__title">树洞</h1>
            <p class="chat__sub">不评判、不打断，只认真听你说</p>
          </div>
        </div>
        <AppButton
          v-if="messages.length > 0"
          size="sm"
          kind="ghost"
          icon="trash"
          @click="confirmClear = true"
        >
          清空对话
        </AppButton>
      </header>

      <div ref="scrollEl" class="chat__scroll">
        <div v-if="loading" class="chat__loading">
          <AppSpinner />
          <span>正在取回你们之前的对话…</span>
        </div>

        <div v-else-if="messages.length === 0" class="chat__empty">
          <span class="chat__empty-icon"><AppIcon name="message" :size="26" /></span>
          <h2 class="chat__empty-title">今天想说点什么？</h2>
          <p class="chat__empty-desc">无论多小的事都可以。不知道从哪说起，就点一句下面的开场。</p>
          <div class="chips">
            <button
              v-for="s in STARTERS"
              :key="s"
              type="button"
              class="chip"
              @click="useStarter(s)"
            >
              {{ s }}
            </button>
          </div>
        </div>

        <template v-else>
          <div v-for="m in messages" :key="m.id" class="turn">
            <div class="bubble bubble--me">
              <p class="bubble__text">{{ m.content }}</p>
            </div>
            <div class="bubble bubble--ai">
              <span class="bubble__avatar"><AppIcon name="leaf" :size="15" /></span>
              <div class="bubble__body">
                <p class="bubble__text">{{ m.aiResponse }}</p>
                <span class="bubble__time">{{ fromNow(m.createTime) }}</span>
              </div>
            </div>
          </div>
        </template>

        <div v-if="sending" class="turn">
          <div class="bubble bubble--me">
            <p class="bubble__text">{{ pendingText }}</p>
          </div>
          <div class="bubble bubble--ai">
            <span class="bubble__avatar"><AppIcon name="leaf" :size="15" /></span>
            <div class="bubble__body">
              <span class="typing"><i></i><i></i><i></i></span>
            </div>
          </div>
        </div>
      </div>

      <div class="composer">
        <textarea
          v-model="draft"
          class="composer__input"
          rows="1"
          placeholder="说点什么吧…（Enter 发送，Shift + Enter 换行）"
          maxlength="2000"
          @keydown.enter="onEnter"
          @input="autoGrow"
          ref="inputEl"
        ></textarea>
        <button
          type="button"
          class="composer__send"
          :disabled="sending || !draft.trim()"
          aria-label="发送"
          @click="send"
        >
          <AppIcon :name="sending ? 'clock' : 'send'" :size="19" />
        </button>
      </div>
      <p class="composer__hint">
        树洞的回应由 AI 生成，可以帮助你梳理情绪，但不能替代专业心理咨询。如果状态持续不好，
        建议联系专业机构或拨打心理援助热线 <strong>12356</strong>。
      </p>
    </div>

    <AppModal v-model="confirmClear" title="清空所有对话？" width="400">
      <p class="modal-text">清空后这些对话将无法恢复。如果只是暂时不想看，可以先关掉页面。</p>
      <template #footer>
        <AppButton kind="secondary" @click="confirmClear = false">再想想</AppButton>
        <AppButton kind="danger" :loading="clearing" @click="doClear">确认清空</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue'
import { chat, clearChatHistory, fetchChatHistory } from '../../api/ai'
import type { AIChat } from '../../api/types'
import { fromNow } from '../../utils/format'
import { toast } from '../../utils/toast'
import AppButton from '../../components/ui/AppButton.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppModal from '../../components/ui/AppModal.vue'
import AppSpinner from '../../components/ui/AppSpinner.vue'

const STARTERS = [
  '今天有点累，不知道为什么',
  '有件事一直放不下',
  '我好像没办法让自己开心起来',
  '想找个人说说话',
]

const messages = ref<AIChat[]>([])
const loading = ref(true)
const sending = ref(false)
const draft = ref('')
const pendingText = ref('')
const confirmClear = ref(false)
const clearing = ref(false)
const scrollEl = ref<HTMLElement | null>(null)
const inputEl = ref<HTMLTextAreaElement | null>(null)

function scrollToBottom(): void {
  nextTick(() => {
    const el = scrollEl.value
    if (el) el.scrollTop = el.scrollHeight
  })
}

function autoGrow(): void {
  const el = inputEl.value
  if (!el) return
  el.style.height = 'auto'
  el.style.height = `${Math.min(el.scrollHeight, 132)}px`
}

function useStarter(text: string): void {
  draft.value = text
  autoGrow()
  inputEl.value?.focus()
}

function onEnter(ev: KeyboardEvent): void {
  if (ev.shiftKey) return
  ev.preventDefault()
  send()
}

async function send(): Promise<void> {
  const text = draft.value.trim()
  if (!text || sending.value) return
  pendingText.value = text
  draft.value = ''
  autoGrow()
  sending.value = true
  scrollToBottom()
  try {
    const res = await chat(text)
    messages.value.push({
      id: Date.now(),
      userId: 0,
      content: text,
      aiResponse: res.response,
      createTime: new Date().toISOString(),
    })
    scrollToBottom()
  } catch (err) {
    // 把内容还给输入框，避免用户白打一遍
    draft.value = text
    autoGrow()
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '树洞刚刚走神了，稍后再试一次')
  } finally {
    sending.value = false
    scrollToBottom()
  }
}

async function doClear(): Promise<void> {
  clearing.value = true
  try {
    await clearChatHistory()
    messages.value = []
    confirmClear.value = false
    toast.success('已清空对话')
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '清空失败，请稍后再试')
  } finally {
    clearing.value = false
  }
}

onMounted(async () => {
  try {
    const list = await fetchChatHistory()
    messages.value = list
  } catch (err) {
    const message = err instanceof Error ? err.message : ''
    toast.error(message || '对话记录加载失败')
  } finally {
    loading.value = false
    scrollToBottom()
  }
})
</script>

<style scoped>
.chat {
  padding: var(--space-3xl) 0 var(--space-4xl);
}
.chat__inner {
  max-width: 860px;
}
.chat__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-l);
  padding-bottom: var(--space-l);
}
.chat__brand {
  display: flex;
  align-items: center;
  gap: var(--space-m);
}
.chat__avatar {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: var(--radius-full);
  background: var(--primary-weak);
  color: var(--primary);
}
.chat__title {
  font-size: var(--font-2xl);
}
.chat__sub {
  font-size: var(--font-s);
  color: var(--text-3);
}

.chat__scroll {
  height: min(58vh, 560px);
  overflow-y: auto;
  padding: var(--space-l) var(--space-s);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
  scroll-behavior: smooth;
}
.chat__loading {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-s);
  height: 100%;
  font-size: var(--font-m);
  color: var(--text-3);
}
.chat__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  text-align: center;
  gap: var(--space-m);
}
.chat__empty-icon {
  display: grid;
  place-items: center;
  width: 56px;
  height: 56px;
  border-radius: var(--radius-full);
  background: var(--primary-weak);
  color: var(--primary);
}
.chat__empty-title {
  font-size: var(--font-2xl);
}
.chat__empty-desc {
  max-width: 420px;
  font-size: var(--font-m);
  line-height: 1.9;
  color: var(--text-3);
}
.chips {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: var(--space-s);
  margin-top: var(--space-s);
}
.chip {
  padding: 8px 14px;
  border-radius: var(--radius-full);
  background: var(--card);
  border: 1px solid var(--line-strong);
  color: var(--text-2);
  font-size: var(--font-s);
  cursor: pointer;
  transition:
    border-color var(--motion-fast) var(--ease-standard),
    color var(--motion-fast) var(--ease-standard),
    transform var(--motion-fast) var(--ease-standard);
}
.chip:hover {
  border-color: var(--primary-border);
  color: var(--primary);
  transform: translateY(-2px);
}

.turn {
  display: flex;
  flex-direction: column;
  gap: var(--space-m);
  margin-bottom: var(--space-xl);
}
.bubble {
  display: flex;
  gap: var(--space-s);
  max-width: 82%;
  animation: rise var(--motion-normal) var(--ease-emphasized);
}
.bubble--me {
  align-self: flex-end;
  flex-direction: row-reverse;
}
.bubble--me .bubble__text {
  background: var(--primary);
  color: var(--primary-contrast);
  border-radius: var(--radius-lg) var(--radius-sm) var(--radius-lg) var(--radius-lg);
}
.bubble--ai .bubble__text {
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: var(--radius-sm) var(--radius-lg) var(--radius-lg) var(--radius-lg);
  box-shadow: var(--shadow-sm);
}
.bubble__avatar {
  flex: none;
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  border-radius: var(--radius-full);
  background: var(--primary-weak);
  color: var(--primary);
}
.bubble__body {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.bubble__text {
  padding: 11px 15px;
  font-size: var(--font-m);
  line-height: 1.9;
  white-space: pre-wrap;
  word-break: break-word;
}
.bubble__time {
  font-size: var(--font-2xs);
  color: var(--text-3);
  padding-left: 2px;
}

.typing {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 14px 16px;
  border-radius: var(--radius-sm) var(--radius-lg) var(--radius-lg) var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line);
  box-shadow: var(--shadow-sm);
}
.typing i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--text-3);
  animation: blink 1.2s infinite ease-in-out;
}
.typing i:nth-child(2) {
  animation-delay: 0.18s;
}
.typing i:nth-child(3) {
  animation-delay: 0.36s;
}

@keyframes blink {
  0%,
  60%,
  100% {
    opacity: 0.25;
    transform: translateY(0);
  }
  30% {
    opacity: 1;
    transform: translateY(-3px);
  }
}
@keyframes rise {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.composer {
  display: flex;
  align-items: flex-end;
  gap: var(--space-m);
  margin-top: var(--space-l);
  padding: var(--space-s) var(--space-s) var(--space-s) var(--space-l);
  border-radius: var(--radius-lg);
  background: var(--card);
  border: 1px solid var(--line-strong);
  box-shadow: var(--shadow-sm);
  transition: border-color var(--motion-fast) var(--ease-standard);
}
.composer:focus-within {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px var(--primary-weak);
}
.composer__input {
  flex: 1;
  resize: none;
  border: none;
  outline: none;
  background: transparent;
  font-family: inherit;
  font-size: var(--font-m);
  line-height: 1.7;
  color: var(--text);
  padding: 8px 0;
  max-height: 132px;
}
.composer__input::placeholder {
  color: var(--text-3);
}
.composer__send {
  flex: none;
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border: none;
  border-radius: var(--radius-md);
  background: var(--primary);
  color: var(--primary-contrast);
  cursor: pointer;
  transition:
    background-color var(--motion-fast) var(--ease-standard),
    transform var(--motion-fast) var(--ease-standard);
}
.composer__send:hover:not(:disabled) {
  background: var(--primary-pressed);
  transform: translateY(-1px);
}
.composer__send:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}
.composer__hint {
  margin-top: var(--space-m);
  font-size: var(--font-xs);
  line-height: 1.8;
  color: var(--text-3);
}
.composer__hint strong {
  color: var(--danger);
}

.modal-text {
  font-size: var(--font-m);
  line-height: 1.9;
  color: var(--text-2);
}

@media (max-width: 640px) {
  .bubble {
    max-width: 94%;
  }
}
</style>
