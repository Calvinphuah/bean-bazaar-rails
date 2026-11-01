<script setup lang="ts">
import BeanCard from "./BeanCard.vue"
import { MAX_RUN_OUTS } from "../rules"
import type { BeanType, TableSnapshot } from "../types"

defineProps<{
  table: TableSnapshot
  beanTypes: Record<string, BeanType>
  // Face-up cards picked for the trade you are building.
  pickedFaceUp: number[]
  pickable: boolean
}>()

const emit = defineEmits<{ pick: [index: number] }>()
</script>

<template>
  <div class="center">
    <div class="piles">
      <div
        class="pile"
        data-tour="deck"
      >
        <div class="stack deck">
          <img
            v-if="table.deck.draw"
            src="/cards/coin_back.webp"
            alt=""
          >
        </div>
        <span>Deck <strong>{{ table.deck.draw }}</strong></span>
      </div>
      <div class="pile">
        <div class="stack discard">
          <img
            v-if="table.deck.discard"
            src="/cards/coin_back.webp"
            alt=""
          >
        </div>
        <span>Discard <strong>{{ table.deck.discard }}</strong></span>
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
.piles { display: grid; grid-template-columns: auto auto; gap: 10px 16px; align-items: end; justify-items: center; }
.pile { display: grid; justify-items: center; gap: 4px; font-size: 12px; font-weight: 800; color: #fff6dc; text-shadow: 0 1px 0 rgba(0, 0, 0, .5); }
.stack {
  width: 86px;
  aspect-ratio: 63 / 88;
  border-radius: 9px;
  border: 2px dashed rgba(255, 246, 220, .4);
}
.stack img { width: 100%; height: 100%; object-fit: cover; border-radius: 6px; display: block; border: 2px solid #fff; }
.stack.deck img { box-shadow: 3px -3px 0 -1px #fff, 6px -6px 0 -2px #f2ead8, 9px -9px 0 -3px #fff, 0 10px 18px rgba(0, 0, 0, .4); }
/* The discard pile looks tossed, not stacked. */
.stack.discard img { transform: rotate(-8deg); box-shadow: 6px 4px 0 -1px #fff, -5px 6px 0 -1px #f2ead8, 0 10px 18px rgba(0, 0, 0, .35); }
.reshuffles { grid-column: 1 / -1; display: flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 800; color: #fff6dc; text-shadow: 0 1px 0 rgba(0, 0, 0, .5); }
.pip { width: 11px; height: 11px; border-radius: 50%; border: 2px solid #fff6dc; }
.pip.used { background: var(--accent); }

.face-up { display: flex; gap: 14px; min-height: 160px; align-items: center; }

.flip-enter-active { transition: transform .45s ease, opacity .45s ease; }
.flip-enter-from { opacity: 0; transform: rotateY(90deg) translateX(-60px) scale(.8); }
.flip-leave-active { transition: all .3s ease; }
.flip-leave-to { opacity: 0; transform: translateY(40px) scale(.85); }
</style>
