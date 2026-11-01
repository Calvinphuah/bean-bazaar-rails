<script setup lang="ts">
import { computed, ref, watch } from "vue"
import BeanCard from "./BeanCard.vue"
import type { BeanKey, BeanType } from "../types"

const CARD_WIDTH = 132
// The fan never gets wider than this, so a big late-game hand still fits the screen.
const MAX_FAN_WIDTH = 1000
const MAX_STEP = 96
const FRONT_SIDE_KEY = "bean-bazaar-front-on-right"

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

// localStorage can throw in private windows; then the hand just starts front-left.
function savedFrontOnRight(): boolean {
  try {
    return localStorage.getItem(FRONT_SIDE_KEY) === "yes"
  } catch {
    return false
  }
}

// Some players like the card to plant next on the right, nearest their mouse hand.
const frontOnRight = ref(savedFrontOnRight())

watch(frontOnRight, (onRight) => {
  try {
    localStorage.setItem(FRONT_SIDE_KEY, onRight ? "yes" : "no")
  } catch {
    // Nothing to do: the choice just lasts for this visit.
  }
})

// Cards in screen order, left to right; `index` is still the card's place in the hand.
const shown = computed(() => {
  const cards = props.hand.map((bean, index) => ({ bean, index }))
  return frontOnRight.value ? cards.reverse() : cards
})

// How far apart neighbouring cards sit: wide for a small hand, tighter as it grows.
const step = computed(() => Math.min(MAX_STEP, (MAX_FAN_WIDTH - CARD_WIDTH) / Math.max(props.hand.length - 1, 1)))
const tilt = computed(() => Math.min(3, 30 / Math.max(props.hand.length, 1)))

// Spread the cards in a gentle arc, like a hand held at a card table.
function fanStyle(position: number): Record<string, string> {
  const middle = (props.hand.length - 1) / 2
  const offset = position - middle
  return {
    transform: `rotate(${offset * tilt.value}deg) translateY(${Math.abs(offset) * tilt.value}px)`,
    marginRight: position === props.hand.length - 1 ? "0" : `${step.value - CARD_WIDTH}px`,
    zIndex: String(position + 1),
  }
}

// The browser photographs the card for the drag ghost right after this handler,
// so drop the glowing border for that one frame and put it back straight after.
function onDragStart(event: DragEvent): void {
  event.dataTransfer?.setData("text/plain", "front")
  const card = event.currentTarget as HTMLElement
  card.classList.add("lifting")
  requestAnimationFrame(() => card.classList.remove("lifting"))
}
</script>

<template>
  <div
    class="hand"
    data-tour="hand"
  >
    <div class="fan">
      <button
        v-if="hand.length > 1"
        class="swap small secondary"
        :title="frontOnRight ? 'Put the card to plant next on the left' : 'Put the card to plant next on the right'"
        @click="frontOnRight = !frontOnRight"
      >
        ⇄ Next card {{ frontOnRight ? "right" : "left" }}
      </button>
      <TransitionGroup name="deal">
        <template
          v-for="({ bean, index }, position) in shown"
          :key="`${bean}-${hand.length - index}`"
        >
          <div
            v-if="beanTypes[bean]"
            class="slot"
            :class="{ front: index === 0 }"
            :style="fanStyle(position)"
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
    </div>
    <span
      v-if="!hand.length"
      class="empty"
    >No cards in hand</span>
  </div>
</template>

<style scoped>
/* Big cards that run off the bottom of the screen, like a hand held at the table. */
.hand { position: relative; display: flex; justify-content: center; align-items: flex-end; padding: 22px 20px 0; margin-bottom: -58px; min-height: 150px; }
.fan { position: relative; display: flex; align-items: flex-end; }
.swap { position: absolute; right: calc(100% + 18px); bottom: 74px; z-index: 60; white-space: nowrap; }
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
.lifting :deep(.card) { box-shadow: none; transition: none; }
.empty { font-size: 13px; color: #fff6dc; padding-bottom: 80px; }
</style>
