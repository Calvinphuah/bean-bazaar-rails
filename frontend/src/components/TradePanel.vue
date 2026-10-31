<script setup lang="ts">
import { computed, ref, watch } from "vue"
import BeanCard from "./BeanCard.vue"
import type { BeanKey, BeanType, TradeOffer } from "../types"

const props = defineProps<{
  faceUp: BeanKey[]
  hand: BeanKey[]
  partners: { index: number; name: string }[]
  beanTypes: Record<string, BeanType>
  busy: boolean
}>()

const emit = defineEmits<{ trade: [offer: TradeOffer]; done: [] }>()

const partnerIndex = ref<number | null>(props.partners[0]?.index ?? null)
const faceUpPicks = ref<number[]>([])
const handPicks = ref<number[]>([])
const askFor = ref<BeanKey[]>([])
const askBean = ref<BeanKey>(Object.keys(props.beanTypes)[0] ?? "")

// Cards move after every trade, so old picks would point at the wrong cards.
watch(() => [ props.faceUp.length, props.hand.length ], () => {
  faceUpPicks.value = []
  handPicks.value = []
  askFor.value = []
})

const canOffer = computed(() =>
  partnerIndex.value !== null && faceUpPicks.value.length + handPicks.value.length + askFor.value.length > 0,
)

function toggle(list: number[], index: number): number[] {
  return list.includes(index) ? list.filter((picked) => picked !== index) : [ ...list, index ]
}

function offer(): void {
  if (partnerIndex.value === null) return
  emit("trade", {
    partner_index: partnerIndex.value,
    face_up_indexes: faceUpPicks.value,
    hand_indexes: handPicks.value,
    partner_beans: askFor.value,
  })
}
</script>

<template>
  <div class="panel trade">
    <h2>Trade</h2>
    <p class="hint">
      Pick cards to give, ask for beans you want, and choose who to offer them to.
      Cards nobody takes stay with you. An offer with nothing asked back is a gift.
    </p>

    <h3>Face-up cards</h3>
    <div class="row">
      <template
        v-for="(bean, index) in faceUp"
        :key="`face-${index}`"
      >
        <button
          v-if="beanTypes[bean]"
          class="card-button"
          :aria-pressed="faceUpPicks.includes(index)"
          @click="faceUpPicks = toggle(faceUpPicks, index)"
        >
          <BeanCard
            :bean="beanTypes[bean]"
            :selected="faceUpPicks.includes(index)"
          />
        </button>
      </template>
      <span
        v-if="!faceUp.length"
        class="muted"
      >None left</span>
    </div>

    <h3>From your hand</h3>
    <div class="row">
      <template
        v-for="(bean, index) in hand"
        :key="`hand-${index}`"
      >
        <button
          v-if="beanTypes[bean]"
          class="card-button"
          :aria-pressed="handPicks.includes(index)"
          @click="handPicks = toggle(handPicks, index)"
        >
          <BeanCard
            :bean="beanTypes[bean]"
            :selected="handPicks.includes(index)"
          />
        </button>
      </template>
    </div>

    <h3>Ask for</h3>
    <div class="ask">
      <select v-model="askBean">
        <option
          v-for="bean in Object.values(beanTypes)"
          :key="bean.key"
          :value="bean.key"
        >
          {{ bean.name }} Bean
        </option>
      </select>
      <button
        class="small secondary"
        @click="askFor = [...askFor, askBean]"
      >
        Add
      </button>
      <span
        v-for="(bean, index) in askFor"
        :key="`ask-${index}`"
        class="chip"
        @click="askFor = askFor.filter((_, position) => position !== index)"
      >
        {{ beanTypes[bean]?.name }} x
      </span>
    </div>

    <div class="footer">
      <label>
        Offer to
        <select v-model="partnerIndex">
          <option
            v-for="partner in partners"
            :key="partner.index"
            :value="partner.index"
          >
            {{ partner.name }}
          </option>
        </select>
      </label>
      <button
        :disabled="busy || !canOffer"
        @click="offer"
      >
        Make offer
      </button>
      <button
        class="secondary"
        :disabled="busy"
        @click="emit('done')"
      >
        Done trading
      </button>
    </div>
  </div>
</template>

<style scoped>
.trade { display: grid; gap: 8px; }
.hint { margin: 0; font-size: 13px; color: var(--muted); }
h3 { font-size: 15px; margin-top: 4px; }
.row { display: flex; gap: 8px; flex-wrap: wrap; min-height: 40px; }
.ask { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.chip {
  background: var(--panel-dark);
  border: 1px solid var(--ink);
  border-radius: 999px;
  padding: 2px 10px;
  font-size: 13px;
  cursor: pointer;
}
.footer { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; margin-top: 6px; }
select { font: inherit; padding: 4px 8px; border-radius: 8px; border: 2px solid var(--ink); }
.muted { color: var(--muted); font-size: 13px; }
</style>
