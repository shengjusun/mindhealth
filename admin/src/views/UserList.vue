<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import type { FormInstance, FormRules } from 'element-plus'
import {
  addUser,
  deleteUser,
  fetchUsers,
  resetUserPassword,
  setUserStatus,
  updateUser,
  type AdminUser,
} from '../api/admin'
import { formatTime } from '../utils/format'

const loading = ref(false)
const keyword = ref('')
const page = ref(1)
const size = 10
const total = ref(0)
const rows = ref<AdminUser[]>([])

const dialogVisible = ref(false)
const editingId = ref<number | null>(null)
const formRef = ref<FormInstance>()
const form = reactive({
  phone: '',
  password: '',
  nickname: '',
  age: undefined as number | undefined,
  gender: '',
})

const isEdit = computed(() => editingId.value !== null)

const rules = computed<FormRules>(() => ({
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确', trigger: 'blur' },
  ],
  ...(isEdit.value
    ? {}
    : {
        password: [
          { required: true, message: '请输入初始密码', trigger: 'blur' },
          { min: 6, max: 64, message: '密码长度为 6~64 位', trigger: 'blur' },
        ],
      }),
}))

const pwdVisible = ref(false)
const pwdTargetId = ref<number | null>(null)
const pwdValue = ref('')

async function load(): Promise<void> {
  loading.value = true
  try {
    const res = await fetchUsers({ page: page.value, size, keyword: keyword.value || undefined })
    rows.value = res.records ?? []
    total.value = res.total ?? 0
  } catch {
    /* 拦截器已提示 */
  } finally {
    loading.value = false
  }
}

function onSearch(): void {
  page.value = 1
  void load()
}

function onReset(): void {
  keyword.value = ''
  page.value = 1
  void load()
}

function openAdd(): void {
  editingId.value = null
  form.phone = ''
  form.password = ''
  form.nickname = ''
  form.age = undefined
  form.gender = ''
  dialogVisible.value = true
}

function openEdit(row: AdminUser): void {
  editingId.value = row.id
  form.phone = row.phone || ''
  form.password = ''
  form.nickname = row.nickname || ''
  form.age = row.age ?? undefined
  form.gender = row.gender || ''
  dialogVisible.value = true
}

async function onSubmit(): Promise<void> {
  if (!formRef.value) return
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return
  try {
    if (editingId.value === null) {
      await addUser({
        phone: form.phone,
        password: form.password,
        nickname: form.nickname || undefined,
        age: form.age,
        gender: form.gender || undefined,
      })
      ElMessage.success('新增成功')
    } else {
      await updateUser(editingId.value, {
        nickname: form.nickname || undefined,
        age: form.age,
        gender: form.gender || undefined,
      })
      ElMessage.success('保存成功')
    }
    dialogVisible.value = false
    await load()
  } catch {
    /* 拦截器已提示 */
  }
}

async function onToggleStatus(row: AdminUser): Promise<void> {
  const next = row.deleted === 1 ? 0 : 1
  const text = next === 1 ? '禁用' : '启用'
  try {
    await ElMessageBox.confirm(`确定${text}用户「${row.nickname || row.phone}」？`, '提示', {
      type: 'warning',
    })
    await setUserStatus(row.id, next)
    ElMessage.success(`${text}成功`)
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

async function onDelete(row: AdminUser): Promise<void> {
  try {
    await ElMessageBox.confirm(
      `确定删除用户「${row.nickname || row.phone}」？此操作不可恢复。`,
      '危险操作',
      { type: 'warning', confirmButtonText: '删除' },
    )
    await deleteUser(row.id)
    ElMessage.success('删除成功')
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

function openResetPwd(row: AdminUser): void {
  pwdTargetId.value = row.id
  pwdValue.value = ''
  pwdVisible.value = true
}

async function onResetPwd(): Promise<void> {
  if (pwdValue.value.length < 6 || pwdValue.value.length > 64) {
    ElMessage.warning('密码长度为 6~64 位')
    return
  }
  if (pwdTargetId.value === null) return
  try {
    await resetUserPassword(pwdTargetId.value, pwdValue.value)
    ElMessage.success('密码已重置')
    pwdVisible.value = false
  } catch {
    /* 拦截器已提示 */
  }
}

onMounted(load)
</script>

<template>
  <el-card shadow="never">
    <template #header>
      <div class="toolbar">
        <el-input
          v-model="keyword"
          placeholder="搜索昵称或手机号"
          clearable
          style="width: 220px"
          @keyup.enter="onSearch"
        />
        <el-button type="primary" @click="onSearch">查询</el-button>
        <el-button @click="onReset">重置</el-button>
        <div class="spacer" />
        <el-button type="primary" @click="openAdd">新增用户</el-button>
      </div>
    </template>

    <el-table v-loading="loading" :data="rows" border stripe>
      <el-table-column prop="id" label="ID" width="70" />
      <el-table-column label="昵称" min-width="120">
        <template #default="{ row }">{{ row.nickname || '-' }}</template>
      </el-table-column>
      <el-table-column label="手机号" min-width="130">
        <template #default="{ row }">{{ row.phone || '-' }}</template>
      </el-table-column>
      <el-table-column label="账号类型" width="110">
        <template #default="{ row }">
          <el-tag :type="row.isHuaweiUser ? 'success' : 'info'" size="small">
            {{ row.isHuaweiUser ? '华为账号' : '手机号' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="性别" width="80">
        <template #default="{ row }">{{ row.gender || '未填' }}</template>
      </el-table-column>
      <el-table-column label="年龄" width="80">
        <template #default="{ row }">{{ row.age ?? '-' }}</template>
      </el-table-column>
      <el-table-column label="注册时间" width="170">
        <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
      </el-table-column>
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.deleted === 1 ? 'danger' : 'success'" size="small">
            {{ row.deleted === 1 ? '已禁用' : '正常' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="260" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link type="primary" @click="openResetPwd(row)">重置密码</el-button>
          <el-button link type="warning" @click="onToggleStatus(row)">
            {{ row.deleted === 1 ? '启用' : '禁用' }}
          </el-button>
          <el-button link type="danger" @click="onDelete(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <div class="pager">
      <el-pagination
        v-model:current-page="page"
        background
        layout="total, prev, pager, next"
        :total="total"
        :page-size="size"
        @current-change="load"
      />
    </div>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑用户' : '新增用户'" width="480px">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="手机号" prop="phone">
          <el-input v-model="form.phone" :disabled="isEdit" placeholder="请输入手机号" />
        </el-form-item>
        <el-form-item v-if="!isEdit" label="初始密码" prop="password">
          <el-input v-model="form.password" type="password" show-password placeholder="6~64 位" />
        </el-form-item>
        <el-form-item label="昵称">
          <el-input v-model="form.nickname" placeholder="选填" />
        </el-form-item>
        <el-form-item label="年龄">
          <el-input-number v-model="form.age" :min="0" :max="150" />
        </el-form-item>
        <el-form-item label="性别">
          <el-select v-model="form.gender" placeholder="选填" clearable style="width: 100%">
            <el-option label="男" value="男" />
            <el-option label="女" value="女" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="onSubmit">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="pwdVisible" title="重置密码" width="420px">
      <el-input v-model="pwdValue" type="password" show-password placeholder="请输入新密码（6~64 位）" />
      <template #footer>
        <el-button @click="pwdVisible = false">取消</el-button>
        <el-button type="primary" @click="onResetPwd">确定</el-button>
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
.pager {
  display: flex;
  justify-content: flex-end;
  margin-top: 12px;
}
</style>