<script setup lang="ts">
import type { BeanType, PlayerState } from "../types"

defineProps<{
  player: PlayerState
  beanTypes: Record<string, BeanType>
  active: boolean
  winner: boolean
}>()
</script>

<template>
  <div
    class="panel opponent"
    :class="{ active }"
  >
    <div class="header">
      <h3>{{ player.name }}</h3>
      <span class="coins">{{ player.coins }} {{ player.coins === 1 ? "coin" : "coins" }}</span>
    </div>
    <div
      v-if="winner"
      class="winner"
    >
      Winner!
    </div>

    <div class="hand">
      <img
        v-for="card in Math.min(player.hand_size, 8)"
        :key="card"
        src="/cards/coin_back.webp"
        alt=""
      >
      <span>{{ player.hand_size }} in hand</span>
    </div>

    <ul class="fields">
      <li
        v-for="(field, index) in player.fields"
        :key="index"
      >
        <template v-if="field.bean">
          <img
            :src="`/cards/${field.bean}.webp`"
            alt=""
          >
          {{ beanTypes[field.bean]?.name }} x{{ field.count }}
        </template>
        <span
          v-else
          class="muted"
        >Empty field</span>
      </li>
    </ul>

    <div
      v-if="player.pending.length"
      class="pending"
    >
      Planting: {{ player.pending.map((bean) => beanTypes[bean]?.name).join(", ") }}
    </div>
  </div>
</template>

<style scoped>
.opponent { min-width: 190px; flex: 1; }
.opponent.active { box-shadow: 0 0 0 3px var(--gold); }
.header { display: flex; justify-content: space-between; align-items: baseline; gap: 8px; }
.coins { font-weight: 800; color: var(--gold-dark); }
.winner { font-weight: 800; color: var(--ok); }
.hand { display: flex; align-items: center; margin: 8px 0; }
.hand img { width: 22px; margin-right: -12px; border-radius: 3px; border: 1px solid var(--ink); }
.hand span { margin-left: 18px; font-size: 13px; }
.fields { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; font-size: 13px; }
.fields li { display: flex; align-items: center; gap: 6px; }
.fields img { width: 20px; height: 26px; object-fit: cover; border-radius: 3px; border: 1px solid var(--ink); }
.muted { color: var(--muted); }
.pending { margin-top: 8px; font-size: 12px; color: var(--accent); }
</style>
