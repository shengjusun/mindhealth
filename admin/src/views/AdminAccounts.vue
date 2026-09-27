<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import type { FormInstance, FormRules } from 'element-plus'
import {
  changeAdminRole,
  createAdmin,
  deleteAdmin,
  fetchAdmins,
  resetAdminPassword,
  type AdminAccount,
  type AdminRole,
} from '../api/admin'
import { formatRole, formatTime } from '../utils/format'
import { getAdminName } from '../auth'

const loading = ref(false)
const rows = ref<AdminAccount[]>([])
const currentName = getAdminName()

function isSelf(row: AdminAccount): boolean {
  return row.username === currentName
}

function isSuper(row: AdminAccount): boolean {
  return String(row.role).trim().toUpperCase() === 'SUPER_ADMIN'
}

/* ===== 新建管理员 ===== */
const createVisible = ref(false)
const createFormRef = ref<FormInstance>()
const createForm = reactive({
  username: '',
  password: '',
  role: 'ADMIN' as AdminRole,
})

const createRules: FormRules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 50, message: '用户名长度需为 3~50 位', trigger: 'blur' },
  ],
  password: [
    { required: true, message: '请输入初始密码', trigger: 'blur' },
    { min: 8, max: 64, message: '密码长度需为 8~64 位', trigger: 'blur' },
  ],
}

/* ===== 重置密码 ===== */
const pwdVisible = ref(false)
const pwdTarget = ref<AdminAccount | null>(null)
const pwdValue = ref('')

/* ===== 改角色 ===== */
const roleVisible = ref(false)
const roleTarget = ref<AdminAccount | null>(null)
const roleValue = ref<AdminRole>('ADMIN')

async function load(): Promise<void> {
  loading.value = true
  try {
    rows.value = await fetchAdmins()
  } catch {
    /* 拦截器已提示 */
  } finally {
    loading.value = false
  }
}

function openCreate(): void {
  createForm.username = ''
  createForm.password = ''
  createForm.role = 'ADMIN'
  createVisible.value = true
}

async function onCreate(): Promise<void> {
  if (!createFormRef.value) return
  const valid = await createFormRef.value.validate().catch(() => false)
  if (!valid) return
  try {
    await createAdmin({
      username: createForm.username.trim(),
      password: createForm.password,
      role: createForm.role,
    })
    ElMessage.success('管理员已创建')
    createVisible.value = false
    await load()
  } catch {
    /* 拦截器已提示（用户名重复、弱口令等都由后端 message 透出） */
  }
}

function openResetPwd(row: AdminAccount): void {
  pwdTarget.value = row
  pwdValue.value = ''
  pwdVisible.value = true
}

async function onResetPwd(): Promise<void> {
  const target = pwdTarget.value
  if (!target) return
  if (pwdValue.value.length < 8 || pwdValue.value.length > 64) {
    ElMessage.warning('密码长度需为 8~64 位')
    return
  }
  try {
    await resetAdminPassword(target.id, pwdValue.value)
    ElMessage.success(`已重置「${target.username}」的密码`)
    pwdVisible.value = false
  } catch {
    /* 拦截器已提示 */
  }
}

function openRole(row: AdminAccount): void {
  roleTarget.value = row
  roleValue.value = isSuper(row) ? 'SUPER_ADMIN' : 'ADMIN'
  roleVisible.value = true
}

async function onSaveRole(): Promise<void> {
  const target = roleTarget.value
  if (!target) return
  try {
    await changeAdminRole(target.id, roleValue.value)
    ElMessage.success('角色已更新')
    roleVisible.value = false
    await load()
  } catch {
    /* 拦截器已提示 */
  }
}

async function onDelete(row: AdminAccount): Promise<void> {
  try {
    await ElMessageBox.confirm(
      `确定删除管理员「${row.username}」？该账号将立即无法登录。`,
      '删除确认',
      { type: 'warning', confirmButtonText: '删除' },
    )
  } catch {
    return
  }
  try {
    await deleteAdmin(row.id)
    ElMessage.success('已删除')
    await load()
  } catch {
    /* 拦截器已提示 */
  }
}

onMounted(() => {
  void load()
})
</script>

<template>
  <div class="page">
    <div class="panel">
      <div class="panel__head">
        <b>管理员账号</b>
        <span class="text-muted" style="margin-left: 10px">
          只有超级管理员能在这里创建、改角色、重置密码和删除
        </span>
        <div class="spacer" />
        <el-button type="primary" @click="openCreate">
          <el-icon><Plus /></el-icon>新建管理员
        </el-button>
      </div>

      <el-table v-loading="loading" :data="rows">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="用户名" min-width="180">
          <template #default="{ row }">
            <span class="strong">{{ row.username }}</span>
            <el-tag v-if="isSelf(row)" size="small" type="info" style="margin-left: 8px">
              当前登录
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="角色" width="140">
          <template #default="{ row }">
            <el-tag :type="isSuper(row) ? 'warning' : 'info'" size="small" effect="dark">
              {{ formatRole(row.role) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="创建时间" width="170">
          <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="更新时间" width="170">
          <template #default="{ row }">{{ formatTime(row.updateTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="230" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openRole(row)">改角色</el-button>
            <el-button link type="primary" @click="openResetPwd(row)">重置密码</el-button>
            <el-button link type="danger" :disabled="isSelf(row)" @click="onDelete(row)">
              删除
            </el-button>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="暂无管理员数据" :image-size="80" />
        </template>
      </el-table>
    </div>

    <el-dialog v-model="createVisible" title="新建管理员" width="480px" align-center>
      <el-form ref="createFormRef" :model="createForm" :rules="createRules" label-width="90px">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="createForm.username" placeholder="3~50 位，用于登录后台" />
        </el-form-item>
        <el-form-item label="初始密码" prop="password">
          <el-input
            v-model="createForm.password"
            type="password"
            show-password
            placeholder="8~64 位，不要用常见弱口令"
          />
        </el-form-item>
        <el-form-item label="角色" prop="role">
          <el-radio-group v-model="createForm.role">
            <el-radio value="ADMIN">管理员</el-radio>
            <el-radio value="SUPER_ADMIN">超级管理员</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <div class="text-muted" style="font-size: 12px; line-height: 1.7">
        超级管理员可以管理其他管理员账号；普通管理员只能使用用户、日记、题库、反馈这些功能。
      </div>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" @click="onCreate">创建</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="pwdVisible" title="重置密码" width="460px" align-center>
      <el-form label-width="90px">
        <el-form-item label="账号">
          <span class="strong">{{ pwdTarget?.username }}</span>
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="pwdValue" type="password" show-password placeholder="8~64 位" />
        </el-form-item>
      </el-form>
      <div class="text-muted" style="font-size: 12px; line-height: 1.7">
        重置后旧密码立刻失效，对方需要用新密码重新登录。
      </div>
      <template #footer>
        <el-button @click="pwdVisible = false">取消</el-button>
        <el-button type="primary" @click="onResetPwd">确认重置</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="roleVisible" title="修改角色" width="460px" align-center>
      <el-form label-width="90px">
        <el-form-item label="账号">
          <span class="strong">{{ roleTarget?.username }}</span>
        </el-form-item>
        <el-form-item label="角色">
          <el-radio-group v-model="roleValue">
            <el-radio value="ADMIN">管理员</el-radio>
            <el-radio value="SUPER_ADMIN">超级管理员</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <div class="text-muted" style="font-size: 12px; line-height: 1.7">
        系统会拒绝降级最后一个超级管理员，避免把管理入口锁死。
      </div>
      <template #footer>
        <el-button @click="roleVisible = false">取消</el-button>
        <el-button type="primary" @click="onSaveRole">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>
