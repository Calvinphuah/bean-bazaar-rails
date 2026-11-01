<script setup lang="ts">
import BeanCard from "./BeanCard.vue"
import type { BeanType, Offer } from "../types"

defineProps<{
  offer: Offer
  fromName: string
  avatar: string
  beanTypes: Record<string, BeanType>
  // You hold every bean the bot asks for, so accepting can work.
  canAccept: boolean
  busy: boolean
}>()

const emit = defineEmits<{ accept: []; decline: [] }>()
</script>

<template>
  <div
    class="offer panel"
    role="dialog"
    aria-label="Trade offer"
  >
    <div class="from">
      <img
        :src="`/cards/${avatar}.webp`"
        alt=""
      >
      <strong>{{ fromName }} wants to trade</strong>
    </div>

    <div class="deal">
      <div class="side">
        <span>You get</span>
        <div class="cards">
          <template
            v-for="(bean, index) in offer.give"
            :key="`give-${index}`"
          >
            <BeanCard
              v-if="beanTypes[bean]"
              :bean="beanTypes[bean]!"
            />
          </template>
          <span
            v-if="!offer.give.length"
            class="muted"
          >Nothing</span>
        </div>
      </div>
      <div class="arrow">
        ⇄
      </div>
      <div class="side">
        <span>You give</span>
        <div class="cards">
          <template
            v-for="(bean, index) in offer.ask"
            :key="`ask-${index}`"
          >
            <BeanCard
              v-if="beanTypes[bean]"
              :bean="beanTypes[bean]!"
            />
          </template>
          <span
            v-if="!offer.ask.length"
            class="muted"
          >Nothing, it's a gift</span>
        </div>
      </div>
    </div>

    <p
      v-if="!canAccept"
      class="missing"
    >
      You don't have the beans {{ fromName }} asked for.
    </p>
    <p class="hint">
      Traded cards must be planted this turn.
    </p>

    <div class="buttons">
      <button
        class="secondary"
        :disabled="busy"
        @click="emit('decline')"
      >
        No thanks
      </button>
      <button
        :disabled="busy || !canAccept"
        @click="emit('accept')"
      >
        Deal!
      </button>
    </div>
  </div>
</template>

<style scoped>
.offer { width: min(460px, 100%); display: grid; gap: 12px; padding: 18px; box-shadow: 0 18px 40px rgba(0, 0, 0, .6); }
.from { display: flex; align-items: center; gap: 10px; font-family: "Fraunces", serif; font-size: 20px; }
.from img { width: 46px; height: 46px; border-radius: 50%; object-fit: cover; object-position: 50% 38%; border: 2px solid var(--gold); }
.deal { display: flex; align-items: center; justify-content: center; gap: 14px; }
.side { display: grid; justify-items: center; gap: 6px; font-weight: 800; font-size: 13px; }
.cards { display: flex; gap: 6px; min-height: 120px; align-items: center; }
.arrow { font-size: 28px; color: var(--muted); }
.missing { margin: 0; color: var(--accent); font-weight: 800; text-align: center; }
.hint { margin: 0; font-size: 12px; color: var(--muted); text-align: center; }
.muted { color: var(--muted); font-size: 13px; }
.buttons { display: flex; justify-content: center; gap: 10px; }
</style>
