<script setup lang="ts">
import { computed } from "vue"
import type { BeanType } from "../types"

const props = withDefaults(defineProps<{
  bean: BeanType
  size?: "full" | "small"
  selected?: boolean
  highlighted?: boolean
}>(), { size: "small", selected: false, highlighted: false })

// Coin stacks for 1..4 coins, skipping steps this bean doesn't pay.
const stacks = computed(() =>
  [ 1, 2, 3, 4 ].flatMap((coins) => {
    const beans = props.bean.meter[String(coins)]
    return beans === undefined ? [] : [ { coins, beans } ]
  }),
)
</script>

<template>
  <div
    class="card"
    :class="[size, { selected, highlighted }]"
  >
    <div class="art">
      <img
        :src="`/cards/${bean.key}.webp`"
        :alt="`${bean.name} Bean`"
      >
      <div class="name">
        {{ bean.name }} Bean
      </div>
      <div class="count">
        {{ bean.copies }}
      </div>
    </div>
    <div
      v-if="size === 'full'"
      class="meter"
    >
      <div
        v-for="stack in stacks"
        :key="stack.coins"
        class="slot"
      >
        <div class="stack">
          <img
            v-for="coin in stack.coins"
            :key="coin"
            src="/cards/coin.webp"
            alt=""
            :style="{ bottom: `${(coin - 1) * 6}px` }"
          >
        </div>
        <div class="beans">
          {{ stack.beans }}
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.card {
  aspect-ratio: 63 / 88;
  background: #fff;
  border-radius: 10px;
  padding: 4px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 6px 14px -8px rgba(0, 0, 0, .7);
  transition: transform .15s ease, box-shadow .15s ease;
}
.card.small { width: 84px; }
.card.full { width: 190px; padding: 6px; border-radius: 14px; }
.card.selected { transform: translateY(-10px); box-shadow: 0 0 0 3px var(--gold), 0 10px 18px -8px rgba(0, 0, 0, .8); }
.card.highlighted { box-shadow: 0 0 0 3px var(--accent), 0 6px 14px -8px rgba(0, 0, 0, .7); }

.art {
  position: relative;
  flex: 1;
  border: 2px solid var(--ink);
  border-radius: 6px;
  overflow: hidden;
}
.art img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }

.name, .count {
  position: absolute;
  font-family: "Fraunces", serif;
  font-weight: 900;
  color: var(--gold);
  -webkit-text-stroke: 3px var(--ink);
  paint-order: stroke fill;
  line-height: 1;
}
.name { top: 4px; left: 5px; right: 5px; font-size: 9px; text-transform: uppercase; }
.count { bottom: 4px; right: 5px; font-size: 18px; }
.full .name { font-size: 15px; top: 7px; left: 8px; -webkit-text-stroke-width: 4px; }
.full .count { font-size: 32px; bottom: 6px; right: 9px; -webkit-text-stroke-width: 5px; }

.meter {
  display: flex;
  justify-content: space-evenly;
  align-items: flex-end;
  margin-top: 5px;
  padding: 4px 2px 3px;
  border: 2px solid var(--ink);
  border-radius: 4px 4px 8px 8px;
  background: var(--panel);
}
.slot { display: flex; flex-direction: column; align-items: center; gap: 3px; width: 25%; }
.stack { position: relative; width: 26px; height: 40px; }
.stack img { position: absolute; left: 0; width: 26px; }
.beans { font-family: "Fraunces", serif; font-weight: 900; font-size: 14px; line-height: 1; color: var(--ink); }
</style>
