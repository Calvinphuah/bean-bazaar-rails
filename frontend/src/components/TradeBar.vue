<script setup lang="ts">
import { computed } from "vue"
import type { BeanKey, BeanType, TradeGive } from "../types"

const props = defineProps<{
  gives: TradeGive[]
  // Beans asked for, with how many of each.
  asks: Record<BeanKey, number>
  beanTypes: Record<string, BeanType>
  status: string
  busy: boolean
}>()

// point: the bean under the pointer, so the table can show it big; null when it leaves.
const emit = defineEmits<{
  ask: [bean: BeanKey, change: number]
  remove: [give: TradeGive]
  point: [bean: BeanKey | null]
  clear: []
  done: []
}>()

const beans = computed(() => Object.values(props.beanTypes))
const hasOffer = computed(() => props.gives.length > 0 || Object.keys(props.asks).length > 0)
</script>

<template>
  <div
    class="trade panel"
    data-tour="trade"
  >
    <div class="section">
      <h3>You give <span class="hint">(click to take back)</span></h3>
      <div class="chips">
        <button
          v-for="give in gives"
          :key="`${give.source}-${give.index}`"
          class="chip-button card-button"
          :title="`Take back ${beanTypes[give.bean]?.name} Bean`"
          :aria-label="`Take back ${beanTypes[give.bean]?.name} Bean`"
          @click="emit('remove', give)"
          @mouseenter="emit('point', give.bean)"
          @mouseleave="emit('point', null)"
        >
          <img
            class="chip"
            :src="`/cards/${give.bean}.webp`"
            alt=""
          >
        </button>
        <span
          v-if="!gives.length"
          class="hint"
        >Click face-up cards or cards in your hand</span>
      </div>
    </div>

    <div class="section">
      <h3>You get <span class="hint">(click to ask, right-click to remove)</span></h3>
      <div class="asks">
        <button
          v-for="bean in beans"
          :key="bean.key"
          class="ask card-button"
          :class="{ chosen: (asks[bean.key] ?? 0) > 0 }"
          :title="`${bean.name} Bean`"
          :aria-label="`Ask for a ${bean.name} bean${asks[bean.key] ? `, ${asks[bean.key]} asked` : ''}`"
          @click="emit('ask', bean.key, 1)"
          @contextmenu.prevent="emit('ask', bean.key, -1)"
          @mouseenter="emit('point', bean.key)"
          @mouseleave="emit('point', null)"
        >
          <img
            :src="`/cards/${bean.key}.webp`"
            alt=""
          >
          <span class="ask-name">{{ bean.name }}</span>
          <span
            v-if="asks[bean.key]"
            class="ask-count"
          >{{ asks[bean.key] }}</span>
        </button>
      </div>
    </div>

    <div class="footer">
      <p
        class="status"
        aria-live="polite"
      >
        {{ status }}
      </p>

      <div class="buttons">
        <button
          class="small secondary"
          :disabled="busy || !hasOffer"
          @click="emit('clear')"
        >
          Clear
        </button>
        <button
          :disabled="busy"
          @click="emit('done')"
        >
          Done trading
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.trade { width: 430px; display: grid; gap: 6px; padding: 10px 12px; box-shadow: 0 10px 24px rgba(0, 0, 0, .4); }
.section { display: grid; gap: 5px; }
h3 { font-size: 14px; }
.hint { font-family: "Plus Jakarta Sans", sans-serif; font-size: 11px; font-weight: 500; color: var(--muted); }
.chips { display: flex; gap: 4px; min-height: 42px; align-items: center; flex-wrap: wrap; }
.chip-button { position: relative; transition: transform .15s ease; }
.chip-button:hover { transform: translateY(-2px); }
.chip { display: block; width: 30px; aspect-ratio: 63 / 88; object-fit: cover; border-radius: 4px; border: 2px solid var(--ink); }
.asks { display: grid; grid-template-columns: repeat(8, 1fr); gap: 2px; }
.ask { position: relative; display: grid; justify-items: center; gap: 2px; padding: 3px; border-radius: 8px; transition: background .15s ease; }
.ask:hover { background: var(--panel-dark); }
.ask.chosen { background: #cfe9c5; }
.ask img { width: 32px; aspect-ratio: 63 / 88; object-fit: cover; border-radius: 4px; border: 2px solid var(--ink); }
.ask-name { font-size: 10px; font-weight: 800; }
.ask-count {
  position: absolute;
  top: -4px;
  right: 6px;
  background: var(--ok);
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  border: 2px solid var(--ink);
  border-radius: 999px;
  padding: 0 5px;
}
.footer { display: flex; gap: 8px; align-items: center; }
.status { margin: 0; flex: 1; font-size: 12px; font-weight: 800; line-height: 1.3; }
.buttons { display: flex; gap: 6px; flex: none; }
</style>
