<script setup lang="ts">
import { computed } from "vue"
import BeanCard from "./BeanCard.vue"
import { MAX_RUN_OUTS } from "../rules"
import type { BeanType, TableSnapshot } from "../types"

// One edge line per this many cards, so a full deck looks thick and a low one thin.
const CARDS_PER_EDGE = 12
const MAX_EDGES = 7
// Tossed cards under the top of the discard pile, each at its own angle.
const DISCARD_TILTS = [-9, 6, -3]

const props = defineProps<{
  table: TableSnapshot
  beanTypes: Record<string, BeanType>
  // Face-up cards picked for the trade you are building.
  pickedFaceUp: number[]
  pickable: boolean
}>()

const emit = defineEmits<{ pick: [index: number] }>()

const deckEdges = computed(() => Math.min(MAX_EDGES, Math.ceil(props.table.deck.draw / CARDS_PER_EDGE)))
const discardTilts = computed(() => DISCARD_TILTS.slice(0, Math.min(props.table.deck.discard, DISCARD_TILTS.length)))

// Card edges peeking out under the top card, like the side of a real deck.
const deckStyle = computed(() => {
  const edges = Array.from({ length: deckEdges.value }, (_, index) => {
    const depth = (index + 1) * 2
    return `0 ${depth}px 0 -1px #f4ecd8, 0 ${depth + 1}px 0 -1px rgba(43, 29, 20, .35)`
  })
  return { boxShadow: [...edges, `0 ${deckEdges.value * 2 + 8}px 16px rgba(0, 0, 0, .35)`].join(", ") }
})
</script>

<template>
  <div class="center">
    <div class="piles">
      <div
        class="pile"
        data-tour="deck"
      >
        <div
          class="stack"
          :class="{ empty: !table.deck.draw }"
        >
          <img
            v-if="table.deck.draw"
            class="card deck-top"
            :style="deckStyle"
            src="/cards/coin_back.webp"
            alt=""
          >
          <span class="count">{{ table.deck.draw }}</span>
        </div>
        <span class="label">Deck</span>
      </div>
      <div class="pile">
        <div
          class="stack"
          :class="{ empty: !table.deck.discard }"
        >
          <img
            v-for="(tilt, index) in discardTilts"
            :key="index"
            class="card tossed"
            :style="{ transform: `rotate(${tilt}deg)` }"
            src="/cards/coin_back.webp"
            alt=""
          >
          <span class="count">{{ table.deck.discard }}</span>
        </div>
        <span class="label">Discard</span>
      </div>
      <div
        class="reshuffles"
        :title="`The game ends when the deck runs out for the ${MAX_RUN_OUTS}rd time`"
      >
        <span>Reshuffles</span>
        <span
          v-for="run in MAX_RUN_OUTS"
          :key="run"
          class="pip"
          :class="{ used: run <= table.deck.run_outs }"
        />
      </div>
    </div>

    <div
      class="face-up"
      data-tour="face-up"
    >
      <TransitionGroup name="flip">
        <template
          v-for="(bean, index) in table.face_up"
          :key="`${bean}-${index}`"
        >
          <button
            v-if="beanTypes[bean] && pickable"
            class="card-button"
            :aria-pressed="pickedFaceUp.includes(index)"
            :aria-label="`Offer the face-up ${beanTypes[bean]!.name} bean`"
            @click="emit('pick', index)"
          >
            <BeanCard
              :bean="beanTypes[bean]!"
              size="medium"
              :selected="pickedFaceUp.includes(index)"
            />
          </button>
          <BeanCard
            v-else-if="beanTypes[bean]"
            :bean="beanTypes[bean]!"
            size="medium"
          />
        </template>
      </TransitionGroup>
    </div>
  </div>
</template>

<style scoped>
.center { display: flex; align-items: center; gap: 28px; }
.piles { display: grid; grid-template-columns: auto auto; gap: 12px 22px; align-items: end; justify-items: center; }
.pile { display: grid; justify-items: center; gap: 22px; }
.label { font-size: 12px; font-weight: 800; letter-spacing: .06em; text-transform: uppercase; color: #fff6dc; text-shadow: 0 1px 0 rgba(0, 0, 0, .5); }
.stack { position: relative; width: 86px; aspect-ratio: 63 / 88; }
/* An empty pile leaves a faint outline where the cards were. */
.stack.empty { border-radius: 9px; border: 2px dashed rgba(255, 246, 220, .35); }
.card { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; display: block; border-radius: 8px; border: 2px solid #fff; }
.tossed { box-shadow: 0 6px 12px rgba(0, 0, 0, .3); }
.count {
  position: absolute;
  top: -9px;
  right: -9px;
  z-index: 2;
  min-width: 28px;
  padding: 2px 6px;
  border-radius: 999px;
  border: 2px solid var(--ink);
  background: var(--panel);
  color: var(--ink);
  font-size: 13px;
  font-weight: 800;
  text-align: center;
  box-shadow: 0 2px 0 var(--ink);
}
.reshuffles { grid-column: 1 / -1; display: flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 800; color: #fff6dc; text-shadow: 0 1px 0 rgba(0, 0, 0, .5); }
.pip { width: 11px; height: 11px; border-radius: 50%; border: 2px solid #fff6dc; }
.pip.used { background: var(--accent); }

.face-up { display: flex; gap: 14px; min-height: 160px; align-items: center; }

.flip-enter-active { transition: transform .45s ease, opacity .45s ease; }
.flip-enter-from { opacity: 0; transform: rotateY(90deg) translateX(-60px) scale(.8); }
.flip-leave-active { transition: all .3s ease; }
.flip-leave-to { opacity: 0; transform: translateY(40px) scale(.85); }
</style>
