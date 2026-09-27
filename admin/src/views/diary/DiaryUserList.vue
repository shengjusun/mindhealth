<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { fetchUsers, type AdminUser } from '../../api/admin'
import { formatTime } from '../../utils/format'

const router = useRouter()

const loading = ref(false)
const keyword = ref('')
const page = ref(1)
const size = ref(10)
const total = ref(0)
const rows = ref<AdminUser[]>([])

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

/** 进入二级页：这个人的日记 */
function openDiaries(row: AdminUser): void {
  void router.push({ path: `/diaries/user/${row.id}` })
}

onMounted(load)
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
        <el-button @click="load">
          <el-icon><Refresh /></el-icon>刷新
        </el-button>
      </div>

      <div class="notice">
        <el-icon><Lock /></el-icon>
        <span>
          日记是用户的私密内容。这里只列出用户，点击「查看日记」进入该用户的日记明细页。
        </span>
      </div>

      <el-table v-loading="loading" :data="rows">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="昵称" min-width="150">
          <template #default="{ row }">
            <div class="user-cell">
              <div class="user-avatar">
                {{ (row.nickname || row.phone || 'U').charAt(0).toUpperCase() }}
              </div>
              <span class="strong text-clip">{{ row.nickname || '未设置昵称' }}</span>
            </div>
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
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.deleted === 1 ? 'danger' : 'success'" size="small" effect="dark">
              {{ row.deleted === 1 ? '已禁用' : '正常' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="日记数" width="110" align="center">
          <template #default="{ row }">
            <el-button v-if="row.diaryCount" link type="primary" @click="openDiaries(row)">
              {{ row.diaryCount }} 篇
            </el-button>
            <span v-else class="zero">0</span>
          </template>
        </el-table-column>
        <el-table-column label="注册时间" width="170">
          <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDiaries(row)">
              查看日记
              <el-icon class="arrow"><ArrowRight /></el-icon>
            </el-button>
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
  </div>
</template>

<style scoped>
.search {
  width: 240px;
}

.notice {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 18px;
  font-size: 12.5px;
  color: var(--text-3);
  background: rgba(77, 124, 254, 0.06);
  border-bottom: 1px solid var(--border);
}

.notice .el-icon {
  color: var(--brand-300);
  flex: none;
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 9px;
  min-width: 0;
}

.user-avatar {
  width: 28px;
  height: 28px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12.5px;
  font-weight: 600;
  color: #fff;
  background: linear-gradient(135deg, #4d7cfe 0%, #8b7cff 100%);
  flex: none;
}

.strong {
  font-weight: 600;
  color: var(--text-1);
}

.zero {
  color: var(--text-3);
  opacity: 0.6;
}

.arrow {
  margin-left: 2px;
  font-size: 11px;
}
</style>
