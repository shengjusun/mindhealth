<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import type { FormInstance, FormRules } from 'element-plus'
import {
  addUser,
  batchOperate,
  deleteUser,
  fetchUserDetail,
  fetchUsers,
  resetUserPassword,
  setUserStatus,
  updateUser,
  type AdminUser,
  type UserDetail,
} from '../api/admin'
import { csvFilename, exportCsv } from '../utils/csv'
import { formatTime } from '../utils/format'

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const keyword = ref('')
const page = ref(1)
const size = ref(10)
const total = ref(0)
const rows = ref<AdminUser[]>([])
const selected = ref<AdminUser[]>([])

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

// 性别显示归一：客户端存英文（male/female/hidden），历史数据与管理端旧表单存过中文，统一转中文展示
const genderText = (value: string | null): string => {
  const v = (value || '').trim().toLowerCase()
  if (v === 'male' || v === 'm' || v === '1' || v === '男') return '男'
  if (v === 'female' || v === 'f' || v === '2' || v === '女') return '女'
  if (v === 'hidden' || v === 'other' || v === 'others' || v === '3' || v === '其他' || v === '隐藏') return '隐藏'
  return '未填'
}

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
const pwdTargetName = ref('')
const pwdValue = ref('')

/* ===== 用户详情抽屉 ===== */
const drawerVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<UserDetail | null>(null)

async function load(): Promise<void> {
  loading.value = true
  try {
    const res = await fetchUsers({
      page: page.value,
      size: size.value,
      keyword: keyword.value || undefined,
    })
    rows.value = res.records ?? []
    total.value = res.total ?? 0
    selected.value = []
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

function onSizeChange(): void {
  page.value = 1
  void load()
}

function onSelectionChange(rowsSelected: AdminUser[]): void {
  selected.value = rowsSelected
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
      `确定删除用户「${row.nickname || row.phone}」？该用户的所有数据将一并清除且不可恢复。`,
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

/* ===== 批量操作 ===== */
async function onBatch(action: 'enable' | 'disable' | 'delete'): Promise<void> {
  const ids = selected.value.map((item) => item.id)
  if (!ids.length) return

  const labels: Record<typeof action, string> = {
    enable: '批量启用',
    disable: '批量禁用',
    delete: '批量删除',
  }
  const warn =
    action === 'delete'
      ? `确定删除选中的 ${ids.length} 个用户？其全部数据将一并清除且不可恢复。`
      : `确定${labels[action]}选中的 ${ids.length} 个用户？`

  try {
    await ElMessageBox.confirm(warn, action === 'delete' ? '危险操作' : '提示', {
      type: 'warning',
      confirmButtonText: '确定',
    })
    const res = await batchOperate('user', action, ids)
    ElMessage.success(`${labels[action]}成功，影响 ${res?.affected ?? ids.length} 条`)
    await load()
  } catch {
    /* 取消或已提示 */
  }
}

function onExport(): void {
  const header = ['ID', '昵称', '手机号', '账号类型', '性别', '年龄', '注册时间', '状态']
  const data = rows.value.map((row) => [
    row.id,
    row.nickname || '',
    row.phone || '',
    row.isHuaweiUser ? '华为账号' : '手机号',
    genderText(row.gender),
    row.age ?? '',
    formatTime(row.createTime),
    row.deleted === 1 ? '已禁用' : '正常',
  ])
  exportCsv(csvFilename('用户列表'), header, data)
  ElMessage.success(`已导出当前页 ${data.length} 条记录`)
}

function openResetPwd(row: AdminUser): void {
  pwdTargetId.value = row.id
  pwdTargetName.value = row.nickname || row.phone || `#${row.id}`
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

/** 按 ID 拉详情。只依赖 ID，所以既能从表格点，也能从外部深链直接调起 */
async function openDetail(userId: number): Promise<void> {
  drawerVisible.value = true
  detailLoading.value = true
  detail.value = null
  try {
    detail.value = await fetchUserDetail(userId)
  } catch {
    /* 拦截器已提示 */
  } finally {
    detailLoading.value = false
  }
}

/** 进入该用户的日记明细页（日记管理的二级页） */
function goUserDiaries(id: number): void {
  drawerVisible.value = false
  void router.push({ path: `/diaries/user/${id}` })
}

/** 进入测评结果页并聚焦该用户 */
function goUserAssessments(id: number): void {
  drawerVisible.value = false
  void router.push({ path: '/assessment-results', query: { userId: String(id) } })
}

onMounted(async () => {
  await load()
  // 支持 /users?detail=<id> 直接调起某个用户的详情抽屉（反馈页的「提交人」靠这个跳过来）
  const target = route.query.detail
  if (target) {
    void openDetail(Number(target))
    void router.replace({ path: '/users' })
  }
})
</script>

<template>
  <div class="page">
    <div class="panel">
      <div class="panel__head">
        <el-input
          v-model="keyword"
          class="search"
          placeholder="搜索昵称或手机号"
          clearable
          @keyup.enter="onSearch"
        >
          <template #prefix>
            <el-icon><Search /></el-icon>
          </template>
        </el-input>
        <el-button type="primary" @click="onSearch">查询</el-button>
        <el-button @click="onReset">重置</el-button>
        <div class="spacer" />
        <el-button @click="onExport">
          <el-icon><Download /></el-icon>导出 CSV
        </el-button>
        <el-button type="primary" @click="openAdd">
          <el-icon><Plus /></el-icon>新增用户
        </el-button>
      </div>

      <div v-if="selected.length" class="batch-bar">
        <el-icon><Select /></el-icon>
        <span>已选中 <b>{{ selected.length }}</b> 项</span>
        <div class="spacer" />
        <el-button size="small" @click="onBatch('enable')">批量启用</el-button>
        <el-button size="small" @click="onBatch('disable')">批量禁用</el-button>
        <el-button size="small" type="danger" plain @click="onBatch('delete')">批量删除</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" @selection-change="onSelectionChange">
        <el-table-column type="selection" width="46" />
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="昵称" min-width="130">
          <template #default="{ row }">
            <span class="strong">{{ row.nickname || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="手机号" min-width="130">
          <template #default="{ row }">
            <span class="mono">{{ row.phone || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="账号类型" width="110">
          <template #default="{ row }">
            <el-tag :type="row.isHuaweiUser ? 'success' : 'info'" size="small" effect="dark">
              {{ row.isHuaweiUser ? '华为账号' : '手机号' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="性别" width="80">
          <template #default="{ row }">{{ genderText(row.gender) }}</template>
        </el-table-column>
        <el-table-column label="年龄" width="80">
          <template #default="{ row }">{{ row.age ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="日记" width="80">
          <template #default="{ row }">
            <el-button
              v-if="row.diaryCount"
              link
              type="primary"
              @click="goUserDiaries(row.id)"
            >
              {{ row.diaryCount }} 篇
            </el-button>
            <span v-else class="text-muted">0</span>
          </template>
        </el-table-column>
        <el-table-column label="注册时间" width="170">
          <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.deleted === 1 ? 'danger' : 'success'" size="small" effect="dark">
              {{ row.deleted === 1 ? '已禁用' : '正常' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="292" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row.id)">详情</el-button>
            <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button link type="primary" @click="openResetPwd(row)">重置密码</el-button>
            <el-button link type="warning" @click="onToggleStatus(row)">
              {{ row.deleted === 1 ? '启用' : '禁用' }}
            </el-button>
            <el-button link type="danger" @click="onDelete(row)">删除</el-button>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="暂无用户数据" :image-size="80" />
        </template>
      </el-table>

      <div class="panel__foot">
        <el-pagination
          v-model:current-page="page"
          v-model:page-size="size"
          background
          :page-sizes="[10, 20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          :total="total"
          @current-change="load"
          @size-change="onSizeChange"
        />
      </div>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? '编辑用户' : '新增用户'"
      width="480px"
      align-center
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="手机号" prop="phone">
          <el-input v-model="form.phone" :disabled="isEdit" placeholder="请输入手机号" />
        </el-form-item>
        <el-form-item v-if="!isEdit" label="初始密码" prop="password">
          <el-input v-model="form.password" type="password" show-password placeholder="6~64 位" />
        </el-form-item>
        <el-form-item label="昵称">
          <el-input v-model="form.nickname" placeholder="选填，留空自动生成" />
        </el-form-item>
        <el-form-item label="年龄">
          <el-input-number v-model="form.age" :min="0" :max="150" controls-position="right" />
        </el-form-item>
        <el-form-item label="性别">
          <el-select v-model="form.gender" placeholder="选填" clearable style="width: 100%">
            <el-option label="男" value="male" />
            <el-option label="女" value="female" />
            <el-option label="隐藏" value="hidden" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="onSubmit">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="pwdVisible" title="重置密码" width="440px" align-center>
      <div class="pwd-tip">
        正在为
        <b>{{ pwdTargetName }}</b>
        重置登录密码
      </div>
      <el-input
        v-model="pwdValue"
        type="password"
        show-password
        size="large"
        placeholder="请输入新密码（6~64 位）"
      />
      <template #footer>
        <el-button @click="pwdVisible = false">取消</el-button>
        <el-button type="primary" @click="onResetPwd">确定重置</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="drawerVisible" title="用户详情" size="480px">
      <div v-loading="detailLoading" class="drawer-body">
        <template v-if="detail">
          <div class="detail-hero">
            <div class="detail-avatar">
              {{ (detail.user.nickname || detail.user.phone || 'U').charAt(0).toUpperCase() }}
            </div>
            <div class="detail-hero-main">
              <div class="detail-name">{{ detail.user.nickname || '未设置昵称' }}</div>
              <div class="detail-sub mono">{{ detail.user.phone || '无手机号' }}</div>
              <div class="detail-tags">
                <el-tag :type="detail.user.isHuaweiUser ? 'success' : 'info'" size="small" effect="dark">
                  {{ detail.user.isHuaweiUser ? '华为账号' : '手机号注册' }}
                </el-tag>
                <el-tag
                  :type="detail.user.deleted === 1 ? 'danger' : 'success'"
                  size="small"
                  effect="dark"
                >
                  {{ detail.user.deleted === 1 ? '已禁用' : '正常' }}
                </el-tag>
              </div>
            </div>
          </div>

          <div class="detail-stats">
            <div class="stat">
              <div class="stat-value">{{ detail.diaryCount }}</div>
              <div class="stat-label">日记</div>
            </div>
            <div class="stat">
              <div class="stat-value">{{ detail.assessmentCount }}</div>
              <div class="stat-label">测评</div>
            </div>
            <div class="stat">
              <div class="stat-value">{{ detail.feedbackCount }}</div>
              <div class="stat-label">反馈</div>
            </div>
            <div class="stat">
              <div class="stat-value">{{ detail.chatCount }}</div>
              <div class="stat-label">AI 对话</div>
            </div>
          </div>

          <div class="detail-block">
            <div class="detail-block__title">基础资料</div>
            <div class="facts">
              <div class="fact"><span>用户 ID</span><b>{{ detail.user.id }}</b></div>
              <div class="fact"><span>性别</span><b>{{ genderText(detail.user.gender) }}</b></div>
              <div class="fact"><span>年龄</span><b>{{ detail.user.age ?? '未填' }}</b></div>
              <div class="fact"><span>个性签名</span><b>{{ detail.user.signature || '未填写' }}</b></div>
              <div class="fact"><span>注册时间</span><b>{{ formatTime(detail.user.createTime) }}</b></div>
              <div class="fact"><span>最近更新</span><b>{{ formatTime(detail.user.updateTime) }}</b></div>
            </div>
          </div>

          <div class="detail-block">
            <div class="detail-block__head">
              <div class="detail-block__title">最近日记</div>
              <el-button
                link
                type="primary"
                size="small"
                @click="goUserDiaries(detail.user.id)"
              >
                查看全部 {{ detail.diaryCount }} 篇
              </el-button>
            </div>
            <el-empty
              v-if="!detail.recentDiaries.length"
              description="暂无日记"
              :image-size="60"
            />
            <ul v-else class="mini-list">
              <li v-for="item in detail.recentDiaries" :key="item.id">
                <span class="mini-title text-clip">{{ item.title || '（无标题）' }}</span>
                <el-tag v-if="item.emotion" size="small" effect="dark" type="info">
                  {{ item.emotion }}
                </el-tag>
                <span class="mini-time">{{ formatTime(item.createTime) }}</span>
              </li>
            </ul>
          </div>

          <div class="detail-block">
            <div class="detail-block__head">
              <div class="detail-block__title">测评记录</div>
              <el-button
                link
                type="primary"
                size="small"
                @click="goUserAssessments(detail.user.id)"
              >
                查看全部 {{ detail.assessmentCount }} 次
              </el-button>
            </div>
            <el-empty
              v-if="!detail.assessmentResults.length"
              description="暂无测评记录"
              :image-size="60"
            />
            <ul v-else class="mini-list">
              <li v-for="item in detail.assessmentResults" :key="item.id">
                <span class="mini-title text-clip">{{ item.title || '未命名量表' }}</span>
                <span class="mini-score">{{ item.score ?? '-' }} 分 · {{ item.level || '-' }}</span>
                <span class="mini-time">{{ formatTime(item.createTime) }}</span>
              </li>
            </ul>
          </div>
        </template>
      </div>
    </el-drawer>
  </div>
</template>

<style scoped>
.search {
  width: 240px;
}

.strong {
  font-weight: 600;
  color: var(--text-1);
}

.pwd-tip {
  margin-bottom: 12px;
  font-size: 13px;
  color: var(--text-2);
}

.pwd-tip b {
  color: var(--text-1);
}

.batch-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 18px;
  font-size: 13px;
  color: var(--brand-300);
  background: linear-gradient(90deg, rgba(77, 124, 254, 0.14) 0%, rgba(77, 124, 254, 0.03) 100%);
  border-bottom: 1px solid var(--border);
}

.batch-bar b {
  color: var(--text-1);
}

/* ===== 抽屉 ===== */
.drawer-body {
  min-height: 200px;
}

.detail-hero {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px;
  border-radius: var(--radius);
  background: linear-gradient(135deg, rgba(77, 124, 254, 0.14) 0%, rgba(34, 211, 197, 0.07) 100%);
  border: 1px solid var(--border);
}

.detail-avatar {
  width: 52px;
  height: 52px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 21px;
  font-weight: 600;
  color: #fff;
  background: linear-gradient(135deg, #4d7cfe 0%, #8b7cff 100%);
  box-shadow: 0 10px 24px -10px rgba(77, 124, 254, 0.9);
  flex: none;
}

.detail-hero-main {
  min-width: 0;
}

.detail-name {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-1);
}

.detail-sub {
  font-size: 12px;
  color: var(--text-3);
}

.detail-tags {
  display: flex;
  gap: 6px;
  margin-top: 6px;
}

.detail-stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
  margin: 16px 0;
}

.stat {
  padding: 12px 8px;
  text-align: center;
  border-radius: var(--radius-sm);
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--border);
}

.stat-value {
  font-size: 19px;
  font-weight: 600;
  color: var(--text-1);
  font-variant-numeric: tabular-nums;
}

.stat-label {
  font-size: 11px;
  color: var(--text-3);
}

.detail-block {
  margin-top: 18px;
}

.detail-block__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 10px;
}

.detail-block__title {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-2);
}

.facts {
  display: flex;
  flex-direction: column;
  gap: 1px;
  border-radius: var(--radius-sm);
  overflow: hidden;
  border: 1px solid var(--border);
}

.fact {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  font-size: 13px;
  background: rgba(255, 255, 255, 0.025);
}

.fact span {
  color: var(--text-3);
  flex: none;
}

.fact b {
  color: var(--text-1);
  font-weight: 500;
  text-align: right;
  word-break: break-all;
}

.mini-list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.mini-list li {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 2px;
  border-bottom: 1px solid var(--border);
  font-size: 13px;
}

.mini-list li:last-child {
  border-bottom: none;
}

.mini-title {
  flex: 1;
  min-width: 0;
  color: var(--text-1);
}

.mini-score {
  font-size: 12px;
  color: var(--brand-300);
  flex: none;
}

.mini-time {
  font-size: 12px;
  color: var(--text-3);
  flex: none;
}
</style>
