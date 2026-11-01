<script setup lang="ts">
import { computed } from "vue"
import BeanCard from "./BeanCard.vue"
import { coinText } from "../rules"
import type { BeanType, TableSnapshot } from "../types"
import type { QuoteAnswer, TradeCounter } from "../api"

const props = defineProps<{
  name: string
  avatar: string
  seat: TableSnapshot["players"][number]
  beanTypes: Record<string, BeanType>
  active: boolean
  winner: boolean
  // A replayed move by this bot, shown as a speech bubble.
  bubble: string | null
  // This bot's live answer to the offer you are building.
  answer: QuoteAnswer | null
  // The smaller deal this bot would take instead, after saying no.
  counter: TradeCounter | null
  canTradeWith: boolean
  // Which edge of the table the bot sits on; its fields face the middle.
  side: "left" | "right" | "top"
}>()

const emit = defineEmits<{ trade: []; counter: [] }>()

// A few backs stand for the whole hand; the count says how many. A wide fan
// would spill off the table edge or under the bot's fields.
const MAX_BACKS = 6
const backs = computed(() => Math.min(props.seat.hand_size, MAX_BACKS))

const beanList = (beans: string[]): string => beans.map((bean) => props.beanTypes[bean]?.name ?? bean).join(", ") || "nothing"
const counterText = computed(() => (props.counter ? `You give ${beanList(props.counter.give)}, you get ${beanList(props.counter.ask)}` : ""))

const ANSWER_LABELS: Record<QuoteAnswer, string> = {
  accept: "Deal!",
  decline: "No thanks",
  missing: "Don't have it",
}
</script>

<template>
  <div
    class="seat"
    :class="[`side-${side}`, { active, winner }]"
  >
    <Transition name="pop">
      <div
        v-if="bubble"
        :key="bubble"
        class="bubble"
      >
        {{ bubble }}
      </div>
    </Transition>

    <div class="player">
      <div class="plate">
        <div class="avatar">
          <img
            :src="`/bots/${avatar}.webp`"
            alt=""
          >
          <span
            v-if="active"
            class="turn-dot"
            aria-label="Playing now"
          />
        </div>
        <div class="who">
          <strong>{{ name }}</strong>
          <span class="coins"><img
            src="/cards/coin.webp"
            alt=""
          >{{ coinText(seat.coins) }}</span>
        </div>
      </div>

      <div
        class="hand"
        :aria-label="`${seat.hand_size} cards in hand`"
      >
        <img
          v-for="card in backs"
          :key="card"
          src="/cards/coin_back.webp"
          alt=""
          :style="{ transform: `rotate(${(card - (backs + 1) / 2) * 5}deg)` }"
        >
        <span class="hand-count">{{ seat.hand_size }}</span>
      </div>
    </div>

    <div class="table-side">
      <div class="fields">
        <div
          v-for="(field, index) in seat.fields"
          :key="index"
          class="field"
          :class="{ empty: !field.bean }"
        >
          <template v-if="field.bean && beanTypes[field.bean]">
            <BeanCard
              :bean="beanTypes[field.bean]!"
              size="mini"
            />
            <span class="badge">{{ field.count }}</span>
          </template>
        </div>
      </div>
    </div>

    <div
      v-if="answer"
      class="answer"
      :class="answer"
    >
      <!-- A yes you can act on is just the button; otherwise the answer itself. -->
      <button
        v-if="answer === 'accept' && canTradeWith"
        class="small"
        @click="emit('trade')"
      >
        Trade with {{ name }}
      </button>
      <!-- A no with a smaller deal attached loads that deal into your trade. -->
      <button
        v-else-if="answer === 'decline' && counter"
        class="small secondary"
        :title="counterText"
        :aria-label="`Use ${name}'s counter-offer: ${counterText}`"
        @click="emit('counter')"
      >
        Counter-offer
      </button>
      <span v-else>{{ ANSWER_LABELS[answer] }}</span>
    </div>
  </div>
</template>

<style scoped>
/* No box: a name plate, a fan of card backs, and the bot's fields on the table,
   always on the side facing the middle of the table. */
.seat {
  position: relative;
  display: grid;
  justify-items: center;
  align-items: center;
  gap: 8px;
}
.player, .table-side { display: grid; justify-items: center; gap: 6px; }
/* A top seat puts its plate and card backs side by side, so it stays short. */
.seat.side-top { grid-template-rows: auto auto; }
.seat.side-top .player { grid-auto-flow: column; align-items: center; gap: 22px; }
.seat.side-left { grid-template-columns: auto auto; }
.seat.side-right { grid-template-columns: auto auto; }
.seat.side-right .player { order: 2; }
.seat.side-right .table-side { order: 1; }
.seat.side-left .fields, .seat.side-right .fields { flex-direction: column; }

.plate {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 14px 4px 4px;
  border-radius: 999px;
  background: rgba(255, 246, 220, .95);
  color: var(--ink);
  box-shadow: 0 6px 14px rgba(0, 0, 0, .3);
  transition: box-shadow .25s ease;
}
.seat.active .plate { box-shadow: 0 0 0 4px var(--gold), 0 0 26px rgba(246, 201, 56, .7); }
.seat.winner .plate { box-shadow: 0 0 0 4px var(--ok); }
.avatar { position: relative; width: 44px; height: 44px; flex: none; }
.avatar img { width: 100%; height: 100%; border-radius: 50%; object-fit: cover; border: 2px solid var(--ink); background: var(--panel); }
.turn-dot { position: absolute; right: -2px; bottom: -2px; width: 14px; height: 14px; border-radius: 50%; background: var(--ok); border: 2px solid var(--ink); animation: pulse 1.2s ease-in-out infinite; }
@keyframes pulse { 50% { transform: scale(1.25); } }
.who { display: grid; line-height: 1.2; }
.who strong { font-family: "Fraunces", serif; font-size: 17px; }
.coins { display: flex; align-items: center; gap: 4px; font-size: 13px; font-weight: 800; color: var(--gold-dark); }
.coins img { width: 16px; }

.hand { position: relative; height: 62px; display: flex; justify-content: center; align-items: flex-end; }
.hand img {
  width: 42px;
  margin: 0 -15px;
  border-radius: 5px;
  border: 2px solid #fff;
  box-shadow: 0 3px 6px rgba(0, 0, 0, .45);
  transform-origin: 50% 150%;
}
.hand-count {
  position: absolute;
  right: -26px;
  bottom: 4px;
  font-size: 12px;
  font-weight: 800;
  background: var(--panel);
  color: var(--ink);
  border-radius: 999px;
  padding: 0 7px;
}

.fields { display: flex; gap: 6px; }
.field { position: relative; width: 42px; height: 58px; border-radius: 6px; display: grid; place-items: center; }
/* An empty field is just a patch of table, so a quiet table doesn't look busy. */
.field.empty { background: rgba(30, 14, 4, .18); box-shadow: inset 0 0 0 1px rgba(255, 246, 220, .12); }
.badge {
  position: absolute;
  top: -6px;
  right: -6px;
  min-width: 20px;
  text-align: center;
  background: var(--accent);
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  border: 2px solid var(--ink);
  border-radius: 999px;
  padding: 0 4px;
}

.bubble {
  position: absolute;
  bottom: calc(100% + 10px);
  left: 50%;
  transform: translateX(-50%);
  z-index: 5;
  width: max-content;
  max-width: 240px;
  background: #fff;
  color: var(--ink);
  font-weight: 800;
  font-size: 13px;
  padding: 7px 12px;
  border-radius: 12px;
  border: 2px solid var(--ink);
  box-shadow: 0 6px 14px rgba(0, 0, 0, .45);
}
/* A top seat touches the header, so its bubble sits beside the plate instead. */
.side-top .bubble { bottom: auto; top: 6px; left: calc(100% + 12px); transform: none; }
.side-top .bubble::after { left: auto; right: 100%; top: 50%; transform: translateY(-50%); border-top-color: transparent; border-right-color: var(--ink); }
.bubble::after {
  content: "";
  position: absolute;
  left: 50%;
  top: 100%;
  transform: translateX(-50%);
  border: 8px solid transparent;
  border-top-color: var(--ink);
}

/* Sits on the bot's hand of card backs, where its reply is easy to spot. */
.answer {
  position: absolute;
  top: 58px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 3;
  white-space: nowrap;
  box-shadow: 0 6px 14px rgba(0, 0, 0, .4);
  display: flex;
  gap: 8px;
  align-items: center;
  font-size: 13px;
  font-weight: 800;
  padding: 4px 10px;
  border-radius: 999px;
  background: var(--panel);
  color: var(--ink);
}
.side-top .answer { top: auto; bottom: -34px; }
.side-left .answer, .side-right .answer { top: auto; bottom: -34px; }
.side-left .answer { left: 0; transform: none; }
.side-right .answer { left: auto; right: 0; transform: none; }
.answer.accept { background: #cfe9c5; }
.answer:has(button) { padding: 0; background: none; box-shadow: none; }
.answer.decline { background: #f4cfcf; }
.answer.missing { background: #e5ddd0; color: var(--muted); }

.pop-enter-active, .pop-leave-active { transition: all .2s ease; }
.pop-enter-from, .pop-leave-to { opacity: 0; transform: translateX(-50%) translateY(6px) scale(.92); }
.side-top .pop-enter-from, .side-top .pop-leave-to { transform: translateY(6px) scale(.92); }
</style>
