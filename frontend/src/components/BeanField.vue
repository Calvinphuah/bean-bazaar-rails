<script setup lang="ts">
import { computed, ref } from "vue"
import BeanCard from "./BeanCard.vue"
import { coinText, coinsFor, nextStep } from "../rules"
import type { BeanType, FieldState } from "../types"

const props = defineProps<{
  field: FieldState
  beanType: BeanType | null
  // Label for the plant button, e.g. "Plant Soy"; null when nothing can be planted here.
  plantLabel: string | null
  canHarvest: boolean
}>()

const emit = defineEmits<{ plant: []; harvest: [] }>()

const dragOver = ref(false)
const coins = computed(() => coinsFor(props.beanType ?? undefined, props.field.count))
const next = computed(() => nextStep(props.beanType ?? undefined, props.field.count))

function onDrop(): void {
  dragOver.value = false
  if (props.plantLabel) emit("plant")
}
</script>

<template>
  <div
    class="field"
    :class="{ empty: beanType === null, droppable: !!plantLabel, over: dragOver }"
    @dragover.prevent="dragOver = !!plantLabel"
    @dragleave="dragOver = false"
    @drop.prevent="onDrop"
  >
    <div
      v-if="beanType"
      class="pile"
    >
      <!-- Card edges peeking out behind the top card show how full the field is. -->
      <span
        v-for="layer in Math.min(field.count - 1, 4)"
        :key="layer"
        class="layer"
        :style="{ transform: `translate(${layer * 3}px, ${layer * -3}px)`, zIndex: -layer }"
      />
      <BeanCard
        :bean="beanType"
        size="small"
      />
      <span class="badge">{{ field.count }}</span>
    </div>
    <div
      v-else
      class="placeholder"
    >
      Empty field
    </div>

    <div class="info">
      <template v-if="beanType">
        <strong v-if="coins">{{ coinText(coins) }}</strong>
        <span v-if="next">{{ next.beans - field.count }} more for {{ coinText(next.coins) }}</span>
        <span v-else>Fully grown, harvest it</span>
      </template>
    </div>

    <div class="actions">
      <!-- The instruction names the bean; the button just says where it goes. -->
      <button
        v-if="plantLabel"
        class="small"
        :aria-label="plantLabel"
        @click="emit('plant')"
      >
        Plant here
      </button>
      <button
        v-if="beanType"
        class="small secondary"
        :disabled="!canHarvest"
        :title="canHarvest ? '' : 'Harvest a field with more beans first'"
        @click="emit('harvest')"
      >
        Harvest
      </button>
    </div>
  </div>
</template>

<style scoped>
.field {
  width: 124px;
  min-height: 190px;
  padding: 8px 6px;
  border-radius: 14px;
  border: 2px dashed transparent;
  background: rgba(60, 30, 10, .22);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  transition: border-color .15s ease, background .15s ease, transform .15s ease;
}
.field.empty { border-color: rgba(255, 246, 220, .4); }
.field.droppable { border-color: var(--gold); border-style: solid; box-shadow: 0 0 18px rgba(246, 201, 56, .5); }
.field.over { background: rgba(246, 201, 56, .2); transform: scale(1.04); }
.pile { position: relative; isolation: isolate; }
.layer {
  position: absolute;
  inset: 0;
  background: #fff;
  border: 1px solid rgba(43, 29, 20, .35);
  border-radius: 9px;
}
.badge {
  position: absolute;
  top: -9px;
  right: -11px;
  min-width: 28px;
  text-align: center;
  background: var(--accent);
  color: #fff;
  font-weight: 800;
  font-size: 15px;
  border: 2px solid var(--ink);
  border-radius: 999px;
  padding: 1px 6px;
}
.placeholder {
  width: 92px;
  aspect-ratio: 63 / 88;
  display: grid;
  place-items: center;
  text-align: center;
  font-size: 12px;
  color: #fff6dc;
}
.info { display: grid; justify-items: center; text-align: center; font-size: 11px; min-height: 30px; color: #fff6dc; text-shadow: 0 1px 0 rgba(0, 0, 0, .5); }
.info strong { font-size: 13px; color: #ffe27a; }
.actions { display: flex; flex-direction: column; gap: 5px; }
</style>
