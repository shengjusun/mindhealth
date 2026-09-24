<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { deleteDiary, fetchDiaries, type DiaryRow } from '../api/admin'
import { formatTime } from '../utils/format'

const loading = ref(false)
const keyword = ref('')
const page = ref(1)
const size = 10
const total = ref(0)
const rows = ref<DiaryRow[]>([])

async function load(): Promise<void> {
  loading.value = true
  try {
    const res = await fetchDiaries({ page: page.value, size, keyword: keyword.value || undefined })
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

async function onDelete(row: DiaryRow): Promise<void> {
  try {
    await ElMessageBox.confirm(`确定删除日记「${row.title || row.id}」？`, '危险操作', {
      type: 'warning',
      confirmButtonText: '删除',
    })
    await deleteDiary(row.id)
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
        <el-input
          v-model="keyword"
          placeholder="搜索标题或内容"
          clearable
          style="width: 220px"
          @keyup.enter="onSearch"
        />
        <el-button type="primary" @click="onSearch">查询</el-button>
        <el-button @click="onReset">重置</el-button>
      </div>
    </template>

    <el-table v-loading="loading" :data="rows" border stripe>
      <el-table-column prop="id" label="ID" width="70" />
      <el-table-column label="作者" width="120">
        <template #default="{ row }">{{ row.author || '-' }}</template>
      </el-table-column>
      <el-table-column label="标题" min-width="140">
        <template #default="{ row }">{{ row.title || '-' }}</template>
      </el-table-column>
      <el-table-column label="内容" min-width="240">
        <template #default="{ row }">
          <el-tooltip :content="row.content" placement="top" :show-after="300">
            <span class="clip">{{ row.content }}</span>
          </el-tooltip>
        </template>
      </el-table-column>
      <el-table-column label="情绪" width="90">
        <template #default="{ row }">
          <el-tag size="small" type="info">{{ row.emotion || '-' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="强度" width="80">
        <template #default="{ row }">{{ row.intensity ?? '-' }}</template>
      </el-table-column>
      <el-table-column label="创建时间" width="170">
        <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="90" fixed="right">
        <template #default="{ row }">
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
  </el-card>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
}
.pager {
  display: flex;
  justify-content: flex-end;
  margin-top: 12px;
}
.clip {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
}
</style>