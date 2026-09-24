<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  addAssessment,
  deleteAssessment,
  fetchAssessments,
  updateAssessment,
  type AssessmentRow,
} from '../api/admin'
import { formatQuestionCount, formatTime } from '../utils/format'

interface OptionDraft {
  key: string
  text: string
  score: number
}

interface QuestionDraft {
  id: number
  title: string
  options: OptionDraft[]
}

const OPTION_KEYS = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']

const loading = ref(false)
const rows = ref<AssessmentRow[]>([])

const dialogVisible = ref(false)
const editingId = ref<number | null>(null)
const form = reactive({ name: '', type: '', description: '' })

const mode = ref<'visual' | 'json'>('visual')
const questions = ref<QuestionDraft[]>([])
const jsonText = ref('')
const jsonError = ref('')

const isEdit = computed(() => editingId.value !== null)
const totalQuestions = computed(() => questions.value.length)

/* ===== 草稿工具 ===== */

function emptyOption(index: number): OptionDraft {
  return { key: OPTION_KEYS[index] ?? `O${index + 1}`, text: '', score: index }
}

function emptyQuestion(id: number): QuestionDraft {
  return {
    id,
    title: '',
    options: [emptyOption(0), emptyOption(1), emptyOption(2), emptyOption(3)],
  }
}

function nextId(): number {
  return questions.value.reduce((max, item) => Math.max(max, item.id), 0) + 1
}

function serialize(): string {
  return JSON.stringify(questions.value, null, 2)
}

/** 解析 JSON 文本到草稿，返回是否成功 */
function parseInto(text: string): boolean {
  jsonError.value = ''
  const trimmed = text.trim()
  if (!trimmed) {
    questions.value = []
    return true
  }
  let parsed: unknown
  try {
    parsed = JSON.parse(trimmed)
  } catch (error) {
    jsonError.value = `JSON 解析失败：${(error as Error).message}`
    return false
  }
  if (!Array.isArray(parsed)) {
    jsonError.value = '题库必须是 JSON 数组'
    return false
  }

  const drafts: QuestionDraft[] = []
  parsed.forEach((raw, index) => {
    const item = (raw ?? {}) as Record<string, unknown>
    const rawOptions = Array.isArray(item.options) ? item.options : []
    const options: OptionDraft[] = rawOptions.map((optRaw, optIndex) => {
      const opt = (optRaw ?? {}) as Record<string, unknown>
      const score = Number(opt.score)
      return {
        key: typeof opt.key === 'string' && opt.key ? opt.key : (OPTION_KEYS[optIndex] ?? `O${optIndex + 1}`),
        text: typeof opt.text === 'string' ? opt.text : '',
        score: Number.isFinite(score) ? score : optIndex,
      }
    })
    drafts.push({
      id: typeof item.id === 'number' ? item.id : index + 1,
      title: typeof item.title === 'string' ? item.title : '',
      options: options.length ? options : [emptyOption(0), emptyOption(1)],
    })
  })

  questions.value = drafts
  return true
}

/* ===== 可视化编辑 ===== */

function addQuestion(): void {
  questions.value.push(emptyQuestion(nextId()))
}

function removeQuestion(index: number): void {
  questions.value.splice(index, 1)
}

function moveQuestion(index: number, delta: number): void {
  const target = index + delta
  if (target < 0 || target >= questions.value.length) return
  const list = questions.value
  const [item] = list.splice(index, 1)
  list.splice(target, 0, item)
}

function addOption(question: QuestionDraft): void {
  if (question.options.length >= OPTION_KEYS.length) {
    ElMessage.warning(`最多支持 ${OPTION_KEYS.length} 个选项`)
    return
  }
  question.options.push(emptyOption(question.options.length))
}

function removeOption(question: QuestionDraft, index: number): void {
  if (question.options.length <= 2) {
    ElMessage.warning('每道题至少保留 2 个选项')
    return
  }
  question.options.splice(index, 1)
  question.options.forEach((opt, i) => {
    opt.key = OPTION_KEYS[i] ?? opt.key
  })
}

/* ===== 模式切换 ===== */

function switchMode(next: 'visual' | 'json'): void {
  if (next === mode.value) return
  if (next === 'json') {
    jsonText.value = serialize()
    jsonError.value = ''
  } else if (!parseInto(jsonText.value)) {
    ElMessage.error('JSON 存在错误，请先修正后再切回可视化编辑')
    return
  }
  mode.value = next
}

function onFormatJson(): void {
  if (!jsonText.value.trim()) {
    ElMessage.warning('题库内容为空')
    return
  }
  try {
    jsonText.value = JSON.stringify(JSON.parse(jsonText.value), null, 2)
    jsonError.value = ''
    ElMessage.success('已格式化')
  } catch (error) {
    jsonError.value = `JSON 解析失败：${(error as Error).message}`
    ElMessage.error('题库 JSON 格式错误，无法格式化')
  }
}

/* ===== 列表 ===== */

async function load(): Promise<void> {
  loading.value = true
  try {
    rows.value = await fetchAssessments()
  } catch {
    /* 拦截器已提示 */
  } finally {
    loading.value = false
  }
}

function openAdd(): void {
  editingId.value = null
  form.name = ''
  form.type = ''
  form.description = ''
  mode.value = 'visual'
  jsonError.value = ''
  jsonText.value = ''
  questions.value = [emptyQuestion(1)]
  dialogVisible.value = true
}

function openEdit(row: AssessmentRow): void {
  editingId.value = row.id
  form.name = row.name || ''
  form.type = row.type || ''
  form.description = row.description || ''
  mode.value = 'visual'
  jsonError.value = ''
  jsonText.value = ''
  if (!parseInto(row.questions || '')) {
    // 原始数据不是合法 JSON 时，退化为源码模式让管理员修正
    mode.value = 'json'
    jsonText.value = row.questions || ''
  }
  if (!questions.value.length && mode.value === 'visual') {
    questions.value = [emptyQuestion(1)]
  }
  dialogVisible.value = true
}

async function onSubmit(): Promise<void> {
  if (!form.name.trim()) {
    ElMessage.warning('请输入量表名称')
    return
  }
  if (mode.value === 'json' && !parseInto(jsonText.value)) {
    ElMessage.error('题库 JSON 格式错误，请检查')
    return
  }
  if (!questions.value.length) {
    ElMessage.warning('请至少添加一道题目')
    return
  }
  for (let i = 0; i < questions.value.length; i++) {
    const q = questions.value[i]
    if (!q.title.trim()) {
      ElMessage.warning(`第 ${i + 1} 题缺少题干`)
      return
    }
    if (q.options.some((opt) => !opt.text.trim())) {
      ElMessage.warning(`第 ${i + 1} 题存在未填写的选项`)
      return
    }
  }

  const payload = {
    name: form.name.trim(),
    type: form.type.trim(),
    description: form.description.trim(),
    questions: serialize(),
  }

  try {
    if (editingId.value === null) {
      await addAssessment(payload)
      ElMessage.success('新增成功')
    } else {
      await updateAssessment(editingId.value, payload)
      ElMessage.success('保存成功')
    }
    dialogVisible.value = false
    await load()
  } catch {
    /* 拦截器已提示 */
  }
}

async function onDelete(row: AssessmentRow): Promise<void> {
  try {
    await ElMessageBox.confirm(
      `确定删除量表「${row.name}」？该量表下的测评记录将一并删除。`,
      '危险操作',
      { type: 'warning', confirmButtonText: '删除' },
    )
    await deleteAssessment(row.id)
    ElMessage.success('删除成功')
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="panel">
      <div class="panel__head">
        <span class="panel__title">量表列表</span>
        <el-tag size="small" type="info" effect="light">共 {{ rows.length }} 套</el-tag>
        <div class="spacer" />
        <el-button size="small" text type="primary" @click="load">刷新</el-button>
        <el-button type="primary" @click="openAdd">
          <el-icon><Plus /></el-icon>新增量表
        </el-button>
      </div>

      <el-table v-loading="loading" :data="rows">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="名称" min-width="170">
          <template #default="{ row }">
            <span class="strong">{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column label="类型" width="110">
          <template #default="{ row }">
            <el-tag size="small" effect="light">{{ row.type || '-' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="描述" min-width="240">
          <template #default="{ row }">
            <el-tooltip :content="row.description" placement="top" :show-after="300">
              <span class="text-clip">{{ row.description || '-' }}</span>
            </el-tooltip>
          </template>
        </el-table-column>
        <el-table-column label="题数" width="90">
          <template #default="{ row }">
            <span class="num">{{ formatQuestionCount(row.questions) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="更新时间" width="170">
          <template #default="{ row }">{{ formatTime(row.updateTime || row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="130" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button link type="danger" @click="onDelete(row)">删除</el-button>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="暂无量表数据" :image-size="80" />
        </template>
      </el-table>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? '编辑量表' : '新增量表'"
      width="820px"
      align-center
      top="6vh"
    >
      <el-form label-width="80px">
        <div class="meta-grid">
          <el-form-item label="名称">
            <el-input v-model="form.name" placeholder="例如：SAS 焦虑自评量表" />
          </el-form-item>
          <el-form-item label="类型">
            <el-input v-model="form.type" placeholder="留空则默认使用名称" />
          </el-form-item>
        </div>
        <el-form-item label="描述">
          <el-input v-model="form.description" type="textarea" :rows="2" placeholder="量表简介" />
        </el-form-item>
      </el-form>

      <div class="editor">
        <div class="editor-head">
          <el-radio-group
            :model-value="mode"
            size="small"
            @change="(val: unknown) => switchMode(val as 'visual' | 'json')"
          >
            <el-radio-button value="visual">可视化编辑</el-radio-button>
            <el-radio-button value="json">JSON 源码</el-radio-button>
          </el-radio-group>
          <el-tag size="small" type="info" effect="light">{{ totalQuestions }} 题</el-tag>
          <div class="spacer" />
          <template v-if="mode === 'visual'">
            <el-button size="small" @click="addQuestion">
              <el-icon><Plus /></el-icon>添加题目
            </el-button>
          </template>
          <template v-else>
            <el-button size="small" text type="primary" @click="onFormatJson">
              <el-icon><MagicStick /></el-icon>格式化
            </el-button>
          </template>
        </div>

        <div v-if="mode === 'visual'" class="editor-body">
          <el-empty v-if="!questions.length" description="暂无题目，点击右上角添加" :image-size="70" />
          <div v-for="(question, qi) in questions" :key="question.id" class="q-card">
            <div class="q-head">
              <span class="q-index">Q{{ qi + 1 }}</span>
              <el-input v-model="question.title" class="q-title" placeholder="请输入题干" />
              <el-button
                size="small"
                text
                :disabled="qi === 0"
                @click="moveQuestion(qi, -1)"
              >
                <el-icon><Top /></el-icon>
              </el-button>
              <el-button
                size="small"
                text
                :disabled="qi === questions.length - 1"
                @click="moveQuestion(qi, 1)"
              >
                <el-icon><Bottom /></el-icon>
              </el-button>
              <el-button size="small" text type="danger" @click="removeQuestion(qi)">
                <el-icon><Delete /></el-icon>
              </el-button>
            </div>

            <div class="o-list">
              <div v-for="(opt, oi) in question.options" :key="oi" class="o-row">
                <span class="o-key">{{ opt.key }}</span>
                <el-input v-model="opt.text" class="o-text" placeholder="选项文案" />
                <el-input-number
                  v-model="opt.score"
                  class="o-score"
                  :min="0"
                  :max="99"
                  controls-position="right"
                />
                <el-button
                  size="small"
                  text
                  type="danger"
                  :disabled="question.options.length <= 2"
                  @click="removeOption(question, oi)"
                >
                  <el-icon><Close /></el-icon>
                </el-button>
              </div>
              <el-button size="small" text type="primary" @click="addOption(question)">
                <el-icon><Plus /></el-icon>添加选项
              </el-button>
            </div>
          </div>
        </div>

        <div v-else class="editor-body">
          <el-input
            v-model="jsonText"
            type="textarea"
            :rows="16"
            class="code-area"
            placeholder="题库 JSON 数组"
          />
          <div v-if="jsonError" class="json-error">{{ jsonError }}</div>
        </div>
      </div>

      <template #footer>
        <div class="dialog-foot">
          <span class="text-muted">保存时会自动校验题库结构</span>
          <div class="spacer" />
          <el-button @click="dialogVisible = false">取消</el-button>
          <el-button type="primary" @click="onSubmit">保存</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.strong {
  font-weight: 600;
  color: var(--text-1);
}

.num {
  font-variant-numeric: tabular-nums;
}

.meta-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 12px;
}

/* ===== 题库编辑器 ===== */
.editor {
  border: 1px solid var(--border);
  border-radius: var(--radius);
  overflow: hidden;
  background: rgba(255, 255, 255, 0.02);
}

.editor-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.03);
}

.editor-body {
  max-height: 380px;
  overflow-y: auto;
  padding: 14px;
}

.q-card {
  margin-bottom: 12px;
  padding: 12px;
  border-radius: var(--radius-sm);
  background: rgba(255, 255, 255, 0.035);
  border: 1px solid var(--border);
}

.q-card:last-child {
  margin-bottom: 0;
}

.q-head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 10px;
}

.q-index {
  flex: none;
  min-width: 34px;
  height: 24px;
  padding: 0 7px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 600;
  border-radius: 7px;
  color: var(--brand-300);
  background: var(--brand-50);
  border: 1px solid rgba(122, 158, 255, 0.24);
}

.q-title {
  flex: 1;
  min-width: 0;
}

.o-list {
  display: flex;
  flex-direction: column;
  gap: 7px;
  padding-left: 42px;
}

.o-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.o-key {
  flex: none;
  width: 22px;
  height: 22px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 600;
  border-radius: 6px;
  color: var(--text-2);
  background: rgba(255, 255, 255, 0.07);
}

.o-text {
  flex: 1;
  min-width: 0;
}

.o-score {
  flex: none;
  width: 104px;
}

.code-area :deep(textarea) {
  font-family: Consolas, Monaco, 'Courier New', monospace;
  font-size: 12px;
  line-height: 1.65;
}

.json-error {
  margin-top: 8px;
  padding: 8px 12px;
  font-size: 12px;
  border-radius: var(--radius-sm);
  color: #ff838a;
  background: rgba(255, 95, 102, 0.1);
  border: 1px solid rgba(255, 95, 102, 0.24);
  word-break: break-all;
}

.dialog-foot {
  display: flex;
  align-items: center;
  gap: 8px;
}
</style>
