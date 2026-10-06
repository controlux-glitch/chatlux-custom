<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { BaseTable } from 'dashboard/components-next/table';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const flows = computed(() => getters['flows/getFlows'].value);
const uiFlags = computed(() => getters['flows/getUIFlags'].value);

onMounted(() => {
  store.dispatch('flows/get');
});

const tableHeaders = computed(() => [
  t('FLOWS.LIST.TABLE_HEADER.NAME'),
  t('FLOWS.LIST.TABLE_HEADER.STATUS'),
  t('FLOWS.LIST.TABLE_HEADER.UPDATED_AT'),
  t('FLOWS.LIST.TABLE_HEADER.ACTIONS'),
]);

const goToNewFlow = () => {
  router.push(accountScopedRoute('flows_new'));
};

const goToEditFlow = flowId => {
  router.push(accountScopedRoute('flows_edit', { flowId }));
};

const goToRuns = flowId => {
  router.push(accountScopedRoute('flows_runs', { flowId }));
};

const publishFlow = async flow => {
  try {
    await store.dispatch('flows/publish', flow.id);
    useAlert(t('FLOWS.PUBLISH.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('FLOWS.PUBLISH.ERROR_MESSAGE'));
  }
};

const cloneFlow = async flow => {
  try {
    await store.dispatch('flows/clone', flow.id);
    useAlert(t('FLOWS.CLONE.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('FLOWS.CLONE.ERROR_MESSAGE'));
  }
};

const deleteFlow = async flow => {
  try {
    await store.dispatch('flows/delete', flow.id);
    useAlert(t('FLOWS.DELETE.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('FLOWS.DELETE.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="sticky top-0 z-10 px-6">
      <div class="w-full max-w-5xl mx-auto">
        <div class="flex items-center justify-between w-full h-20 gap-2">
          <span class="text-heading-1 text-n-slate-12">
            {{ t('FLOWS.HEADER') }}
          </span>
          <Button
            :label="t('FLOWS.HEADER_BTN_TXT')"
            icon="i-lucide-plus"
            size="sm"
            @click="goToNewFlow"
          />
        </div>
      </div>
    </header>
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-5xl mx-auto py-4">
        <div
          v-if="uiFlags.isFetching"
          class="flex justify-center items-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <BaseTable
          v-else
          :headers="tableHeaders"
          :items="flows"
          :no-data-message="t('FLOWS.LIST.EMPTY')"
        >
          <template #row="{ items }">
            <tr v-for="flow in items" :key="flow.id">
              <td class="py-2">
                <button
                  class="text-n-blue-text hover:underline"
                  @click="goToEditFlow(flow.id)"
                >
                  {{ flow.name }}
                </button>
              </td>
              <td class="py-2 text-n-slate-11">{{ flow.status }}</td>
              <td class="py-2 text-n-slate-11">
                {{ new Date(flow.updated_at).toLocaleString() }}
              </td>
              <td class="py-2 flex gap-2">
                <Button
                  variant="faded"
                  size="xs"
                  :label="t('FLOWS.LIST.ACTIONS.RUNS')"
                  @click="goToRuns(flow.id)"
                />
                <Button
                  variant="faded"
                  size="xs"
                  :label="t('FLOWS.LIST.ACTIONS.PUBLISH')"
                  @click="publishFlow(flow)"
                />
                <Button
                  variant="faded"
                  size="xs"
                  :label="t('FLOWS.LIST.ACTIONS.CLONE')"
                  @click="cloneFlow(flow)"
                />
                <Button
                  variant="faded"
                  color="ruby"
                  size="xs"
                  :label="t('FLOWS.LIST.ACTIONS.DELETE')"
                  @click="deleteFlow(flow)"
                />
              </td>
            </tr>
          </template>
        </BaseTable>
      </div>
    </main>
  </section>
</template>
