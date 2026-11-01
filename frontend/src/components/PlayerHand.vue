<script setup lang="ts">
import { computed } from "vue"
import BeanCard from "./BeanCard.vue"
import type { BeanKey, BeanType } from "../types"

const CARD_WIDTH = 132
// The fan never gets wider than this, so a big late-game hand still fits the screen.
const MAX_FAN_WIDTH = 1000
const MAX_STEP = 96

const props = defineProps<{
  hand: BeanKey[]
  beanTypes: Record<string, BeanType>
  // The front card can be dragged onto a field right now.
  canPlantFront: boolean
  // Cards can be picked for a trade right now.
  pickable: boolean
  picked: number[]
}>()

const emit = defineEmits<{ pick: [index: number] }>()

// How far apart neighbouring cards sit: wide for a small hand, tighter as it grows.
const step = computed(() => Math.min(MAX_STEP, (MAX_FAN_WIDTH - CARD_WIDTH) / Math.max(props.hand.length - 1, 1)))
const tilt = computed(() => Math.min(3, 30 / Math.max(props.hand.length, 1)))

// Spread the cards in a gentle arc, like a hand held at a card table.
function fanStyle(index: number): Record<string, string> {
  const middle = (props.hand.length - 1) / 2
  const offset = index - middle
  return {
    transform: `rotate(${offset * tilt.value}deg) translateY(${Math.abs(offset) * tilt.value}px)`,
    marginRight: index === props.hand.length - 1 ? "0" : `${step.value - CARD_WIDTH}px`,
    zIndex: String(index + 1),
  }
}

function onDragStart(event: DragEvent): void {
  event.dataTransfer?.setData("text/plain", "front")
}
</script>

<template>
  <div
    class="hand"
    data-tour="hand"
  >
    <TransitionGroup name="deal">
      <template
        v-for="(bean, index) in hand"
        :key="`${bean}-${hand.length - index}`"
      >
        <div
          v-if="beanTypes[bean]"
          class="slot"
          :class="{ front: index === 0 }"
          :style="fanStyle(index)"
        >
          <span
            v-if="index === 0"
            class="next"
          >Plant next</span>
          <button
            v-if="pickable"
            class="card-button"
            :aria-pressed="picked.includes(index)"
            :aria-label="`Offer your ${beanTypes[bean]!.name} bean`"
            @click="emit('pick', index)"
          >
            <BeanCard
              :bean="beanTypes[bean]!"
              size="large"
              :selected="picked.includes(index)"
            />
          </button>
          <div
            v-else
            :draggable="index === 0 && canPlantFront"
            :class="{ grabbable: index === 0 && canPlantFront }"
            @dragstart="onDragStart"
          >
            <BeanCard
              :bean="beanTypes[bean]!"
              size="large"
              :highlighted="index === 0 && canPlantFront"
            />
          </div>
        </div>
      </template>
    </TransitionGroup>
    <span
      v-if="!hand.length"
      class="empty"
    >No cards in hand</span>
  </div>
</template>

<style scoped>
/* Big cards that run off the bottom of the screen, like a hand held at the table. */
.hand { display: flex; justify-content: center; align-items: flex-end; padding: 22px 20px 0; margin-bottom: -58px; min-height: 150px; }
.slot { position: relative; transform-origin: 50% 130%; transition: transform .18s ease, margin .2s ease; }
.slot:hover { transform: translateY(-46px) !important; z-index: 50 !important; }
.next {
  position: absolute;
  top: -14px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 3;
  white-space: nowrap;
  background: var(--accent);
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  padding: 1px 8px;
  border-radius: 999px;
  border: 2px solid var(--ink);
}
.grabbable { cursor: grab; }
.grabbable:active { cursor: grabbing; }
.empty { font-size: 13px; color: #fff6dc; padding-bottom: 80px; }
</style>
