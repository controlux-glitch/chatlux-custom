<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import FlowsAPI from 'dashboard/api/flows';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { BaseTable } from 'dashboard/components-next/table';

const { t } = useI18n();
const route = useRoute();
const flowId = computed(() => route.params.flowId);

const isFetching = ref(true);
const runs = ref([]);
const selectedRun = ref(null);
const isFetchingEvents = ref(false);

const tableHeaders = computed(() => [
  t('FLOWS.RUNS.TABLE_HEADER.CONVERSATION'),
  t('FLOWS.RUNS.TABLE_HEADER.STATUS'),
  t('FLOWS.RUNS.TABLE_HEADER.CURRENT_NODE'),
  t('FLOWS.RUNS.TABLE_HEADER.STARTED_AT'),
]);

const fetchRuns = async () => {
  isFetching.value = true;
  try {
    const response = await FlowsAPI.runs(flowId.value);
    runs.value = response.data.payload;
  } finally {
    isFetching.value = false;
  }
};

const openRun = async run => {
  isFetchingEvents.value = true;
  try {
    const response = await FlowsAPI.run(flowId.value, run.id);
    selectedRun.value = response.data;
  } finally {
    isFetchingEvents.value = false;
  }
};

const closeRun = () => {
  selectedRun.value = null;
};

onMounted(fetchRuns);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="sticky top-0 z-10 px-6">
      <div class="w-full max-w-5xl mx-auto h-20 flex items-center">
        <span class="text-heading-1 text-n-slate-12">
          {{ t('FLOWS.RUNS.HEADER') }}
        </span>
      </div>
    </header>
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-5xl mx-auto py-4">
        <div
          v-if="isFetching"
          class="flex justify-center items-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <BaseTable
          v-else
          :headers="tableHeaders"
          :items="runs"
          :no-data-message="t('FLOWS.RUNS.EMPTY')"
        >
          <template #row="{ items }">
            <tr
              v-for="run in items"
              :key="run.id"
              class="cursor-pointer hover:bg-n-alpha-1"
              @click="openRun(run)"
            >
              <td class="py-2">{{ run.conversation_id }}</td>
              <td class="py-2 text-n-slate-11">{{ run.status }}</td>
              <td class="py-2 text-n-slate-11">{{ run.current_node_id }}</td>
              <td class="py-2 text-n-slate-11">
                {{ new Date(run.started_at).toLocaleString() }}
              </td>
            </tr>
          </template>
        </BaseTable>

        <div
          v-if="selectedRun"
          class="fixed inset-0 bg-black/40 flex items-center justify-center z-20"
          @click.self="closeRun"
        >
          <div
            class="bg-n-solid-1 rounded-lg shadow-lg w-full max-w-2xl max-h-[80vh] overflow-y-auto p-4"
          >
            <div class="flex items-center justify-between mb-3">
              <span class="text-heading-2 text-n-slate-12">
                {{ t('FLOWS.RUNS.DETAIL.TITLE', { id: selectedRun.id }) }}
              </span>
              <button class="text-n-slate-11" @click="closeRun">
                <Icon icon="i-lucide-x" />
              </button>
            </div>
            <Spinner v-if="isFetchingEvents" />
            <ol v-else class="flex flex-col gap-2">
              <li
                v-for="event in selectedRun.events"
                :key="event.id"
                class="border border-n-weak rounded-md p-2"
              >
                <div class="flex justify-between text-body-main">
                  <span class="text-n-slate-12">{{ event.node_type }}</span>
                  <span class="text-n-slate-11">{{ event.status }}</span>
                </div>
                <div class="text-caption text-n-slate-11">
                  {{
                    t('FLOWS.RUNS.DETAIL.NEXT_NODE_SUMMARY', {
                      nextNode: event.next_node_id || '—',
                      duration: event.duration_ms || 0,
                    })
                  }}
                </div>
                <div
                  v-if="event.error_message"
                  class="text-n-ruby-9 text-body-main"
                >
                  {{ event.error_message }}
                </div>
              </li>
            </ol>
          </div>
        </div>
      </div>
    </main>
  </section>
</template>
