<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { debounce } from '@chatwoot/utils';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';

import { VueFlow, useVueFlow, MarkerType } from '@vue-flow/core';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import FlowNode from '../components/FlowNode.vue';
import { NODE_TYPE_DEFINITIONS, getNodeDefinition } from '../constants';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const route = useRoute();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const flowId = computed(() => route.params.flowId);
const isNewFlow = computed(() => !flowId.value);

const flowName = ref(t('FLOWS.EDITOR.DEFAULT_NAME'));
const flowInboxIds = ref([]);
const nodes = ref([]);
const edges = ref([]);
const selectedNodeId = ref(null);
const isSaving = ref(false);
const isPublishing = ref(false);
let nextNodeSeq = 1;
let nextButtonSeq = 1;

const inboxOptions = computed(() => getters['inboxes/getInboxes'].value);
const teamOptions = computed(() => getters['teams/getTeams'].value);
const agentOptions = computed(() => getters['agents/getAgents'].value);
const labelOptions = computed(() => getters['labels/getLabels'].value);

onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('teams/get');
  store.dispatch('agents/get');
  store.dispatch('labels/get');
});

const { onConnect, addEdges, onNodeClick, onPaneClick } = useVueFlow();

const selectedNode = computed(() =>
  nodes.value.find(node => node.id === selectedNodeId.value)
);

const selectedNodeDefinition = computed(() =>
  selectedNode.value
    ? getNodeDefinition(selectedNode.value.data.nodeType)
    : null
);

const outputLabelFor = (sourceNodeId, sourceHandle) => {
  if (!sourceHandle) return undefined;

  const sourceNode = nodes.value.find(node => node.id === sourceNodeId);
  if (!sourceNode) return undefined;

  if (sourceNode.data.nodeType === 'CONDITION') {
    return sourceHandle === 'yes' ? 'Sí' : 'No';
  }
  if (sourceNode.data.nodeType === 'WHATSAPP_BUTTONS') {
    const button = (sourceNode.data.params.buttons || []).find(
      candidate => candidate.id === sourceHandle
    );
    return button?.title;
  }
  return undefined;
};

onConnect(connection => {
  addEdges([
    {
      ...connection,
      label: outputLabelFor(connection.source, connection.sourceHandle),
      markerEnd: MarkerType.ArrowClosed,
    },
  ]);
});

onNodeClick(({ node }) => {
  selectedNodeId.value = node.id;
});

onPaneClick(() => {
  selectedNodeId.value = null;
});

const buildDefinitionPayload = () => ({
  nodes: nodes.value.map(node => ({
    id: node.id,
    type: node.data?.nodeType,
    position: node.position,
    params: node.data?.params || {},
  })),
  edges: edges.value.map(edge => ({
    id: edge.id,
    source: edge.source,
    target: edge.target,
    source_handle: edge.sourceHandle || undefined,
  })),
});

const loadFromDefinition = definition => {
  const def = definition || { nodes: [], edges: [] };
  nodes.value = (def.nodes || []).map(node => ({
    id: node.id,
    type: 'flowNode',
    position: node.position || { x: 0, y: 0 },
    data: { nodeType: node.type, params: node.params || {} },
  }));
  edges.value = (def.edges || []).map(edge => ({
    id: edge.id,
    source: edge.source,
    target: edge.target,
    sourceHandle: edge.source_handle,
    label: outputLabelFor(edge.source, edge.source_handle),
    markerEnd: MarkerType.ArrowClosed,
  }));
};

onMounted(async () => {
  if (!isNewFlow.value) {
    const flow = await store.dispatch('flows/show', flowId.value);
    flowName.value = flow.name;
    flowInboxIds.value = flow.inbox_ids || [];
    loadFromDefinition(flow.definition);
  }
});

const persistFlow = async () => {
  isSaving.value = true;
  try {
    if (isNewFlow.value) {
      const created = await store.dispatch('flows/create', {
        name: flowName.value,
        inbox_ids: flowInboxIds.value,
        definition: buildDefinitionPayload(),
      });
      router.replace(accountScopedRoute('flows_edit', { flowId: created.id }));
    } else {
      await store.dispatch('flows/update', {
        id: flowId.value,
        name: flowName.value,
        inbox_ids: flowInboxIds.value,
        definition: buildDefinitionPayload(),
      });
    }
  } catch (error) {
    useAlert(t('FLOWS.EDITOR.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const autosave = debounce(() => {
  if (!isNewFlow.value) persistFlow();
}, 1200);

watch([nodes, edges, flowName, flowInboxIds], autosave, { deep: true });

const saveManually = async () => {
  await persistFlow();
  useAlert(t('FLOWS.EDITOR.SAVE_SUCCESS'));
};

const publishFlow = async () => {
  if (isNewFlow.value) await persistFlow();
  isPublishing.value = true;
  try {
    await store.dispatch('flows/publish', flowId.value);
    useAlert(t('FLOWS.PUBLISH.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('FLOWS.PUBLISH.ERROR_MESSAGE'));
  } finally {
    isPublishing.value = false;
  }
};

const addNode = nodeDefinition => {
  const id = `n${Date.now()}_${(nextNodeSeq += 1)}`;
  nodes.value = [
    ...nodes.value,
    {
      id,
      type: 'flowNode',
      position: {
        x: 200 + nodes.value.length * 20,
        y: 100 + nodes.value.length * 60,
      },
      data: { nodeType: nodeDefinition.type, params: {} },
    },
  ];
};

const removeSelectedNode = () => {
  if (!selectedNodeId.value) return;
  nodes.value = nodes.value.filter(node => node.id !== selectedNodeId.value);
  edges.value = edges.value.filter(
    edge =>
      edge.source !== selectedNodeId.value &&
      edge.target !== selectedNodeId.value
  );
  selectedNodeId.value = null;
};

const updateSelectedNodeParam = (key, value) => {
  if (!selectedNode.value) return;
  selectedNode.value.data.params = {
    ...selectedNode.value.data.params,
    [key]: value,
  };
};

const selectedNodeButtons = computed(
  () => selectedNode.value?.data.params.buttons || []
);

const addButtonOption = () => {
  if (!selectedNode.value) return;
  const id = `btn_${(nextButtonSeq += 1)}`;
  updateSelectedNodeParam('buttons', [
    ...selectedNodeButtons.value,
    { id, title: '' },
  ]);
};

const updateButtonOption = (index, key, value) => {
  const buttons = selectedNodeButtons.value.map((button, i) =>
    i === index ? { ...button, [key]: value } : button
  );
  updateSelectedNodeParam('buttons', buttons);
};

const removeButtonOption = index => {
  updateSelectedNodeParam(
    'buttons',
    selectedNodeButtons.value.filter((_, i) => i !== index)
  );
};
</script>

<template>
  <div class="flex flex-col w-full h-full bg-n-surface-1">
    <header
      class="flex items-center justify-between h-16 px-4 border-b border-n-weak gap-2"
    >
      <div class="flex items-center gap-3">
        <Input
          v-model="flowName"
          class="max-w-sm"
          :placeholder="t('FLOWS.EDITOR.NAME_PLACEHOLDER')"
        />
        <label class="flex items-center gap-2 text-body-main text-n-slate-11">
          {{ t('FLOWS.EDITOR.INBOXES_LABEL') }}
          <select
            v-model="flowInboxIds"
            multiple
            class="reset-base border border-n-weak rounded-md p-1 text-sm min-w-[10rem]"
          >
            <option
              v-for="inbox in inboxOptions"
              :key="inbox.id"
              :value="inbox.id"
            >
              {{ inbox.name }}
            </option>
          </select>
        </label>
      </div>
      <div class="flex items-center gap-2">
        <span v-if="isSaving" class="text-body-main text-n-slate-11">
          {{ t('FLOWS.EDITOR.SAVING') }}
        </span>
        <Button
          variant="outline"
          size="sm"
          :label="t('FLOWS.EDITOR.SAVE')"
          @click="saveManually"
        />
        <Button
          size="sm"
          :is-loading="isPublishing"
          :label="t('FLOWS.EDITOR.PUBLISH')"
          @click="publishFlow"
        />
      </div>
    </header>

    <div class="flex flex-1 min-h-0">
      <aside class="w-60 border-r border-n-weak p-3 overflow-y-auto">
        <p class="text-heading-3 text-n-slate-12 mb-2">
          {{ t('FLOWS.EDITOR.NODE_PALETTE') }}
        </p>
        <div class="flex flex-col gap-1">
          <Button
            v-for="nodeDefinition in NODE_TYPE_DEFINITIONS"
            :key="nodeDefinition.type"
            variant="faded"
            size="xs"
            justify="start"
            :label="nodeDefinition.label"
            @click="addNode(nodeDefinition)"
          />
        </div>
      </aside>

      <div class="flex-1 min-w-0">
        <VueFlow v-model:nodes="nodes" v-model:edges="edges" fit-view-on-init>
          <template #node-flowNode="nodeProps">
            <FlowNode v-bind="nodeProps" />
          </template>
        </VueFlow>
      </div>

      <aside
        v-if="selectedNode && selectedNodeDefinition"
        class="w-80 border-l border-n-weak p-3 overflow-y-auto"
      >
        <p class="text-heading-3 text-n-slate-12 mb-1">
          {{ selectedNodeDefinition.label }}
        </p>
        <p class="text-caption text-n-slate-11 mb-3">
          {{ selectedNodeDefinition.description }}
        </p>

        <div
          v-for="field in selectedNodeDefinition.fields"
          :key="field.key"
          class="mb-3"
        >
          <template v-if="field.type !== 'buttons'">
            <label class="text-body-main text-n-slate-11 block mb-1">
              {{ field.label }}
            </label>
            <select
              v-if="field.type === 'select'"
              class="reset-base w-full border border-n-weak rounded-md p-2 text-sm bg-n-solid-1"
              :value="selectedNode.data.params[field.key] || ''"
              @change="updateSelectedNodeParam(field.key, $event.target.value)"
            >
              <option value="" disabled>{{ field.label }}</option>
              <option
                v-for="option in field.options"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
            <select
              v-else-if="field.type === 'team'"
              class="reset-base w-full border border-n-weak rounded-md p-2 text-sm bg-n-solid-1"
              :value="selectedNode.data.params[field.key] || ''"
              @change="updateSelectedNodeParam(field.key, $event.target.value)"
            >
              <option value="">{{ t('FLOWS.EDITOR.SELECT_TEAM') }}</option>
              <option
                v-for="team in teamOptions"
                :key="team.id"
                :value="team.id"
              >
                {{ team.name }}
              </option>
            </select>
            <select
              v-else-if="field.type === 'agent'"
              class="reset-base w-full border border-n-weak rounded-md p-2 text-sm bg-n-solid-1"
              :value="selectedNode.data.params[field.key] || ''"
              @change="updateSelectedNodeParam(field.key, $event.target.value)"
            >
              <option value="">{{ t('FLOWS.EDITOR.SELECT_AGENT') }}</option>
              <option
                v-for="agent in agentOptions"
                :key="agent.id"
                :value="agent.id"
              >
                {{ agent.name }}
              </option>
            </select>
            <select
              v-else-if="field.type === 'label'"
              class="reset-base w-full border border-n-weak rounded-md p-2 text-sm bg-n-solid-1"
              :value="selectedNode.data.params[field.key] || ''"
              @change="updateSelectedNodeParam(field.key, $event.target.value)"
            >
              <option value="">{{ t('FLOWS.EDITOR.SELECT_LABEL') }}</option>
              <option
                v-for="label in labelOptions"
                :key="label.id"
                :value="label.title"
              >
                {{ label.title }}
              </option>
            </select>
            <input
              v-else-if="field.type === 'number'"
              type="number"
              class="reset-base w-full border border-n-weak rounded-md p-2 text-sm"
              :value="selectedNode.data.params[field.key] || ''"
              @input="updateSelectedNodeParam(field.key, $event.target.value)"
            />
            <textarea
              v-else-if="field.type === 'textarea'"
              class="reset-base w-full border border-n-weak rounded-md p-2 text-sm"
              rows="4"
              :placeholder="field.placeholder"
              :value="selectedNode.data.params[field.key] || ''"
              @input="updateSelectedNodeParam(field.key, $event.target.value)"
            />
            <input
              v-else
              type="text"
              class="reset-base w-full border border-n-weak rounded-md p-2 text-sm"
              :placeholder="field.placeholder"
              :value="selectedNode.data.params[field.key] || ''"
              @input="updateSelectedNodeParam(field.key, $event.target.value)"
            />
          </template>

          <template v-else>
            <div class="flex items-center justify-between mb-1">
              <label class="text-body-main text-n-slate-11">
                {{ field.label }}
              </label>
              <Button
                variant="faded"
                size="xs"
                :label="t('FLOWS.EDITOR.ADD_BUTTON')"
                @click="addButtonOption"
              />
            </div>
            <p
              v-if="selectedNodeButtons.length > 3"
              class="text-caption text-n-amber-11 mb-2"
            >
              {{ t('FLOWS.EDITOR.BUTTONS_LIST_WARNING') }}
            </p>
            <div class="flex flex-col gap-2">
              <div
                v-for="(button, index) in selectedNodeButtons"
                :key="button.id"
                class="flex items-center gap-1"
              >
                <input
                  type="text"
                  class="reset-base flex-1 border border-n-weak rounded-md p-2 text-sm"
                  :placeholder="t('FLOWS.EDITOR.BUTTON_TITLE_PLACEHOLDER')"
                  :value="button.title"
                  @input="
                    updateButtonOption(index, 'title', $event.target.value)
                  "
                />
                <Button
                  variant="ghost"
                  color="ruby"
                  size="xs"
                  icon="i-lucide-trash-2"
                  @click="removeButtonOption(index)"
                />
              </div>
            </div>
          </template>
        </div>

        <Button
          variant="faded"
          color="ruby"
          size="xs"
          class="mt-3"
          :label="t('FLOWS.EDITOR.DELETE_NODE')"
          @click="removeSelectedNode"
        />
      </aside>
    </div>
  </div>
</template>
