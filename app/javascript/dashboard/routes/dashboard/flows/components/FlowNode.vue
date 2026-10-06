<script setup>
import { computed } from 'vue';
import { Handle, Position } from '@vue-flow/core';
import { getNodeDefinition } from '../constants';

const props = defineProps({
  data: { type: Object, required: true },
});

const definition = computed(() => getNodeDefinition(props.data.nodeType));

// CONDITION and WHATSAPP_BUTTONS have more than one way out of the node, so
// each output gets its own named Handle (id = the edge's source_handle) —
// every other node type keeps a single unnamed output.
const outputs = computed(() => {
  if (props.data.nodeType === 'CONDITION') {
    return [
      { id: 'yes', label: 'Sí' },
      { id: 'no', label: 'No' },
    ];
  }
  if (props.data.nodeType === 'WHATSAPP_BUTTONS') {
    return (props.data.params?.buttons || []).map((button, index) => ({
      id: button.id,
      label: button.title || `Botón ${index + 1}`,
    }));
  }
  return [];
});
</script>

<template>
  <div
    class="rounded-md border-2 border-n-slate-6 bg-n-solid-1 px-3 py-2 min-w-[180px] text-body-main text-n-slate-12"
  >
    <Handle type="target" :position="Position.Top" class="!bg-n-slate-9" />

    <div class="font-medium">{{ definition?.label || data.nodeType }}</div>

    <div
      v-if="outputs.length"
      class="mt-2 flex flex-col gap-1 border-t border-n-weak pt-1"
    >
      <div
        v-for="output in outputs"
        :key="output.id"
        class="relative flex items-center justify-between gap-3 text-caption text-n-slate-11"
      >
        <span>{{ output.label }}</span>
        <Handle
          :id="output.id"
          type="source"
          :position="Position.Right"
          class="!static !translate-x-0 !translate-y-0 !bg-n-slate-9"
        />
      </div>
    </div>
    <Handle
      v-else
      type="source"
      :position="Position.Bottom"
      class="!bg-n-slate-9"
    />
  </div>
</template>
