<script setup lang="ts">
import BeanCard from "./BeanCard.vue"
import type { BeanType, FieldState } from "../types"

defineProps<{
  field: FieldState
  beanType: BeanType | null
  // Label for the plant button, e.g. "Plant Soy"; null hides it.
  plantLabel: string | null
  canHarvest: boolean
}>()

const emit = defineEmits<{ plant: []; harvest: [] }>()
</script>

<template>
  <div
    class="field"
    :class="{ empty: beanType === null }"
  >
    <div
      v-if="beanType"
      class="pile"
    >
      <!-- Card edges peeking out behind the top card show how full the field is. -->
      <span
        v-for="layer in Math.min(field.count - 1, 3)"
        :key="layer"
        class="layer"
        :style="{ transform: `translate(${layer * 3}px, ${layer * -3}px)`, zIndex: -layer }"
      />
      <BeanCard :bean="beanType" />
      <span class="badge">x{{ field.count }}</span>
    </div>
    <div
      v-else
      class="placeholder"
    >
      Empty field
    </div>

    <div class="info">
      <span v-if="beanType">Worth {{ field.coins }} {{ field.coins === 1 ? "coin" : "coins" }}</span>
    </div>

    <div class="actions">
      <button
        v-if="plantLabel"
        class="small"
        @click="emit('plant')"
      >
        {{ plantLabel }}
      </button>
      <button
        v-if="beanType"
        class="small secondary"
        :disabled="!canHarvest"
        @click="emit('harvest')"
      >
        Harvest
      </button>
    </div>
  </div>
</template>

<style scoped>
.field {
  width: 132px;
  min-height: 200px;
  padding: 10px;
  border-radius: 12px;
  border: 2px dashed rgba(246, 239, 227, .35);
  background: rgba(0, 0, 0, .18);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}
.pile { position: relative; isolation: isolate; }
.layer {
  position: absolute;
  inset: 0;
  background: #fff;
  border: 1px solid rgba(43, 29, 20, .35);
  border-radius: 10px;
}
.badge {
  position: absolute;
  top: -8px;
  right: -10px;
  background: var(--accent);
  color: #fff;
  font-weight: 800;
  font-size: 13px;
  border: 2px solid var(--ink);
  border-radius: 999px;
  padding: 1px 7px;
}
.placeholder {
  width: 84px;
  aspect-ratio: 63 / 88;
  display: grid;
  place-items: center;
  text-align: center;
  font-size: 12px;
  color: rgba(246, 239, 227, .55);
}
.info { font-size: 12px; min-height: 16px; }
.actions { display: flex; flex-direction: column; gap: 6px; }
</style>
