<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  addAssessment,
  deleteAssessment,
  fetchAssessments,
  updateAssessment,
  type AssessmentRow,
} from '../api/admin'
import { formatQuestionCount, formatTime } from '../utils/format'

const QUESTION_TEMPLATE = JSON.stringify(
  [
    {
      id: 1,
      title: '题目示例：最近一周你的感受是？',
      options: [
        { key: 'A', text: '选项一', score: 0 },
        { key: 'B', text: '选项二', score: 1 },
        { key: 'C', text: '选项三', score: 2 },
        { key: 'D', text: '选项四', score: 3 },
      ],
    },
  ],
  null,
  2,
)

const loading = ref(false)
const rows = ref<AssessmentRow[]>([])

const dialogVisible = ref(false)
const editingId = ref<number | null>(null)
const form = reactive({ name: '', type: '', description: '', questions: '' })

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
  form.questions = QUESTION_TEMPLATE
  dialogVisible.value = true
}

function openEdit(row: AssessmentRow): void {
  editingId.value = row.id
  form.name = row.name || ''
  form.type = row.type || ''
  form.description = row.description || ''
  form.questions = row.questions || ''
  dialogVisible.value = true
}

async function onSubmit(): Promise<void> {
  if (!form.name.trim()) {
    ElMessage.warning('请输入量表名称')
    return
  }
  if (form.questions.trim()) {
    try {
      const parsed = JSON.parse(form.questions)
      if (!Array.isArray(parsed)) {
        ElMessage.warning('题库 JSON 必须是数组')
        return
      }
    } catch {
      ElMessage.error('题库 JSON 格式错误，请检查')
      return
    }
  }
  try {
    if (editingId.value === null) {
      await addAssessment({ ...form })
      ElMessage.success('新增成功')
    } else {
      await updateAssessment(editingId.value, { ...form })
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
    await ElMessageBox.confirm(`确定删除量表「${row.name}」？`, '危险操作', {
      type: 'warning',
      confirmButtonText: '删除',
    })
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
  <el-card shadow="never">
    <template #header>
      <div class="toolbar">
        <span>共 {{ rows.length }} 套量表</span>
        <div class="spacer" />
        <el-button size="small" @click="load">刷新</el-button>
        <el-button type="primary" @click="openAdd">新增量表</el-button>
      </div>
    </template>

    <el-table v-loading="loading" :data="rows" border stripe>
      <el-table-column prop="id" label="ID" width="70" />
      <el-table-column label="名称" min-width="160">
        <template #default="{ row }">{{ row.name }}</template>
      </el-table-column>
      <el-table-column label="类型" width="110">
        <template #default="{ row }">
          <el-tag size="small">{{ row.type || '-' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="描述" min-width="240">
        <template #default="{ row }">
          <el-tooltip :content="row.description" placement="top" :show-after="300">
            <span class="clip">{{ row.description }}</span>
          </el-tooltip>
        </template>
      </el-table-column>
      <el-table-column label="题数" width="80">
        <template #default="{ row }">{{ formatQuestionCount(row.questions) }}</template>
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
    </el-table>

    <el-dialog
      v-model="dialogVisible"
      :title="editingId === null ? '新增量表' : '编辑量表'"
      width="720px"
    >
      <el-form label-width="80px">
        <el-form-item label="名称">
          <el-input v-model="form.name" placeholder="例如：SAS 焦虑自评量表" />
        </el-form-item>
        <el-form-item label="类型">
          <el-input v-model="form.type" placeholder="例如：SAS" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="form.description" type="textarea" :rows="2" />
        </el-form-item>
        <el-form-item label="题库 JSON">
          <el-input v-model="form.questions" type="textarea" :rows="16" class="code-area" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="onSubmit">保存</el-button>
      </template>
    </el-dialog>
  </el-card>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
}
.spacer {
  flex: 1;
}
.clip {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
}
.code-area :deep(textarea) {
  font-family: Consolas, Monaco, 'Courier New', monospace;
  font-size: 12px;
  line-height: 1.5;
}
</style>