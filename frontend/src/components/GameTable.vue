<script setup lang="ts">
import { computed, ref, toRef, watch } from "vue"
import BeanCard from "./BeanCard.vue"
import BrandMark from "./BrandMark.vue"
import BeanField from "./BeanField.vue"
import BotSeat from "./BotSeat.vue"
import GameLog from "./GameLog.vue"
import OfferCard from "./OfferCard.vue"
import PhaseTracker from "./PhaseTracker.vue"
import PlayerHand from "./PlayerHand.vue"
import TableCenter from "./TableCenter.vue"
import TradeBar from "./TradeBar.vue"
import TutorialGuide from "./TutorialGuide.vue"
import { MAX_FIELDS, MAX_HAND_PLANTS, THIRD_FIELD_PRICE, accepts, canHarvest, coinText } from "../rules"
import { useTrade } from "../useTrade"
import type { BeanKey, BeanType, FieldState, GameState, LogEvent, Move, TableSnapshot } from "../types"

const props = defineProps<{
  game: GameState
  table: TableSnapshot
  busy: boolean
  replaying: LogEvent | null
  showTutorial: boolean
  move: (next: Move) => Promise<boolean>
}>()

const emit = defineEmits<{ leave: []; skip: []; tutorialDone: []; tutorial: [] }>()

// Each bot gets a bean character as its face at the table.
const AVATARS = ["chili", "green", "soy", "red"]
// Seat spots around the table, clockwise from your left, by number of bots.
const SEAT_SPOTS: Record<number, string[]> = {
  2: ["top-left", "top-right"],
  3: ["left", "top", "right"],
  4: ["left", "top-left", "top-right", "right"],
}

const showLog = ref(false)
const showPayouts = ref(false)
const pickedPending = ref<number | null>(null)
// The bean under the pointer in your hand or the trade bar, shown big with its coin row.
const pointedBean = ref<BeanKey | null>(null)

const beanTypes = computed<Record<string, BeanType>>(() =>
  Object.fromEntries(props.game.bean_types.map((bean) => [bean.key, bean])),
)
const you = computed(() => props.game.you)
const me = computed(() => props.game.players[you.value])
const myTable = computed(() => props.table.players[you.value])
const hand = computed<BeanKey[]>(() => me.value?.hand ?? [])
const frontCard = computed(() => hand.value[0] ?? null)
const pointedType = computed(() => (pointedBean.value ? beanTypes.value[pointedBean.value] : undefined))
const pointedCopies = computed(() => hand.value.filter((bean) => bean === pointedBean.value).length)
const myFields = computed<FieldState[]>(() => myTable.value?.fields ?? [])

const seats = computed(() => {
  const count = props.game.players.length
  const spots = SEAT_SPOTS[count - 1] ?? []
  return Array.from({ length: count - 1 }, (_, offset) => {
    const index = (you.value + offset + 1) % count
    return { index, spot: spots[offset] ?? "top", avatar: AVATARS[offset] ?? "blue" }
  })
})
const avatarOf = (index: number): string => seats.value.find((seat) => seat.index === index)?.avatar ?? "blue"
const nameOf = (index: number | null): string => (index === null ? "" : props.game.players[index]?.name ?? "")

// Nothing is clickable while bot moves replay; the live state decides what you may do.
const live = computed(() => !props.replaying && !props.busy && !props.game.over)
const myTurn = computed(() => props.game.active_index === you.value && !props.game.over)
const canPlantFromHand = computed(() =>
  live.value && myTurn.value && props.game.phase === "plant" && props.game.hand_plants < MAX_HAND_PLANTS && frontCard.value !== null,
)
const canFlip = computed(() =>
  live.value && myTurn.value && props.game.phase === "plant" && (props.game.hand_plants > 0 || hand.value.length === 0),
)
const isTrading = computed(() => live.value && myTurn.value && props.game.phase === "trade" && !props.game.offer)
const pendingIndex = computed(() => {
  const pending = me.value?.pending ?? []
  if (!live.value || props.game.phase !== "plant_pending" || pending.length === 0) return null
  return pickedPending.value !== null && pickedPending.value < pending.length ? pickedPending.value : 0
})
const pendingCard = computed(() => (pendingIndex.value === null ? null : me.value?.pending[pendingIndex.value] ?? null))
// Beans you got in trades this turn: locked away from trading until they're planted.
const lockedPending = computed(() => (!props.replaying && props.game.phase === "trade" ? me.value?.pending ?? [] : []))
const pendingHint = computed(() => {
  const card = pendingCard.value
  if (!card) return ""
  if (!myFields.value.some((field) => accepts(field, card))) return `No field can take your ${beanName(card)}: harvest a field first.`
  return `Drag your ${beanName(card)} onto a field, or press Plant ${beanName(card)}.`
})
const canBuyField = computed(() =>
  live.value && !!me.value && me.value.fields.length < MAX_FIELDS && me.value.coins >= THIRD_FIELD_PRICE,
)

const offer = computed(() => (props.replaying ? null : props.game.offer))
const canAcceptOffer = computed(() => {
  const remaining = [...hand.value]
  return (offer.value?.ask ?? []).every((bean) => {
    const index = remaining.indexOf(bean)
    if (index === -1) return false
    remaining.splice(index, 1)
    return true
  })
})

const trade = useTrade(toRef(props, "game"), isTrading, props.move)

watch(() => me.value?.pending.length, () => { pickedPending.value = null })

const turnLabel = computed(() => {
  if (props.game.over) return "Game over"
  return props.table.active_index === you.value ? "Your turn" : `${nameOf(props.table.active_index)}'s turn`
})

function beanName(bean: BeanKey): string {
  return beanTypes.value[bean]?.name ?? bean
}

// One clear instruction for what to do right now.
const instruction = computed(() => {
  if (props.replaying) return `${nameOf(props.replaying.player) || "The table"} is playing...`
  if (props.game.over) return ""
  if (offer.value) return `${nameOf(offer.value.from)} is offering you a deal.`
  // The traded-beans panel gives its own instructions.
  if (pendingCard.value) return ""
  if (!myTurn.value) return `${nameOf(props.game.active_index)} is playing...`
  if (props.game.phase === "plant" && props.game.hand_plants === 0) {
    const card = frontCard.value
    if (!card) return "Your hand is empty, so flip 2 cards."
    if (!myFields.value.some((field) => accepts(field, card))) return `No field can take your ${beanName(card)}: harvest a field first.`
    return `Drag your ${beanName(card)} onto a field, or press Plant.`
  }
  if (props.game.phase === "plant") return "Plant your next card too, or flip 2 cards to start trading."
  return "Make an offer, or press Done trading."
})

// A replayed move, minus the bot's own name, for its speech bubble.
function bubbleFor(index: number): string | null {
  const event = props.replaying
  if (!event || event.player !== index || event.type === "turn") return null
  const name = nameOf(index)
  const text = event.text.startsWith(`${name} `) ? event.text.slice(name.length + 1) : event.text
  return text.charAt(0).toUpperCase() + text.slice(1)
}

function plantLabel(field: FieldState): string | null {
  if (canPlantFromHand.value && frontCard.value && accepts(field, frontCard.value)) return `Plant ${beanName(frontCard.value)}`
  if (pendingCard.value && accepts(field, pendingCard.value)) return `Plant ${beanName(pendingCard.value)}`
  return null
}

function plantInto(fieldIndex: number): void {
  if (canPlantFromHand.value) props.move({ type: "plant_from_hand", field_index: fieldIndex })
  else if (pendingIndex.value !== null) {
    props.move({ type: "plant_pending", pending_index: pendingIndex.value, field_index: fieldIndex })
  }
}

const standings = computed(() =>
  props.game.players
    .map((player, index) => ({ index, name: player.name, coins: player.coins }))
    .sort((left, right) => right.coins - left.coins),
)
const youWon = computed(() => props.game.winners.includes(you.value))
</script>

<template>
  <div class="game">
    <header class="topbar">
      <BrandMark size="small" />
      <PhaseTracker
        :phase="table.phase"
        :turn-label="turnLabel"
      />
      <div class="tools">
        <button
          class="tool"
          @click="emit('tutorial')"
        >
          How to play
        </button>
        <button
          class="tool"
          @click="showPayouts = true"
        >
          Payouts
        </button>
        <button
          class="tool"
          :aria-pressed="showLog"
          @click="showLog = !showLog"
        >
          Log
        </button>
        <button
          class="tool"
          @click="emit('leave')"
        >
          New game
        </button>
      </div>
    </header>

    <main
      class="felt"
      data-tour="seats"
    >
      <BotSeat
        v-for="seat in seats"
        :key="seat.index"
        :class="`spot-${seat.spot}`"
        :name="nameOf(seat.index)"
        :avatar="seat.avatar"
        :seat="table.players[seat.index]!"
        :bean-types="beanTypes"
        :active="table.active_index === seat.index && !game.over"
        :winner="game.over && game.winners.includes(seat.index)"
        :bubble="bubbleFor(seat.index)"
        :answer="isTrading ? trade.answers.value[seat.index] ?? null : null"
        :can-trade-with="isTrading && trade.answers.value[seat.index] === 'accept'"
        :side="seat.spot === 'left' || seat.spot === 'right' ? seat.spot : 'top'"
        @trade="trade.tradeWith(seat.index)"
      />

      <div class="middle">
        <TableCenter
          :table="table"
          :bean-types="beanTypes"
          :picked-face-up="trade.pickedFaceUp.value"
          :pickable="isTrading"
          @pick="trade.toggleFaceUp"
        />
      </div>

      <div class="row my-spot">
        <div
          class="farm"
          data-tour="fields"
        >
          <BeanField
            v-for="(field, index) in myFields"
            :key="index"
            :field="field"
            :bean-type="field.bean ? beanTypes[field.bean] ?? null : null"
            :plant-label="live ? plantLabel(field) : null"
            :can-harvest="live && canHarvest(myFields, index)"
            @plant="plantInto(index)"
            @harvest="move({ type: 'harvest', field_index: index })"
          />
          <button
            v-if="canBuyField"
            class="buy-field"
            @click="move({ type: 'buy_third_field' })"
          >
            + Buy a 3rd field<br><small>{{ THIRD_FIELD_PRICE }} coins</small>
          </button>
        </div>

        <div
          class="action"
          data-tour="action"
        >
          <div class="plate-row">
            <!-- Your plate matches the bots': who you are and what you've earned. -->
            <div
              class="my-plate"
              :class="{ active: myTurn && !replaying }"
            >
              <img
                src="/cards/coin.webp"
                alt=""
              >
              <strong>You</strong>
              <span>{{ coinText(myTable?.coins ?? 0) }}</span>
            </div>
            <div
              v-if="lockedPending.length"
              class="locked"
            >
              <span>Plant after trading:</span>
              <template
                v-for="(bean, index) in lockedPending"
                :key="`${bean}-${index}`"
              >
                <BeanCard
                  v-if="beanTypes[bean]"
                  :bean="beanTypes[bean]!"
                  size="mini"
                />
              </template>
            </div>
          </div>
          <TradeBar
            v-if="isTrading"
            :gives="trade.gives.value"
            :asks="trade.asks.value"
            :bean-types="beanTypes"
            :status="trade.status.value"
            :busy="busy"
            @ask="trade.changeAsk"
            @remove="trade.removeGive"
            @point="pointedBean = $event"
            @clear="trade.clear"
            @done="move({ type: 'end_trading' })"
          />
          <p
            v-else-if="instruction"
            class="instruction"
            :class="{ thinking: !!replaying }"
          >
            <span
              v-if="replaying || busy"
              class="spinner"
              aria-hidden="true"
            />
            {{ instruction }}
          </p>
          <div class="buttons">
            <button
              v-if="replaying"
              class="secondary"
              @click="emit('skip')"
            >
              Skip ▶▶
            </button>
            <button
              v-if="canFlip"
              class="big"
              @click="move({ type: 'flip_cards' })"
            >
              Flip 2 cards
            </button>
          </div>

          <div
            v-if="pendingCard && me"
            class="pending panel"
          >
            <div class="pending-head">
              <strong>Plant your traded beans</strong>
              <span class="left">{{ me.pending.length }} left</span>
            </div>
            <p class="pending-rule">
              Traded beans can't be traded again. Plant every one now.
            </p>
            <div class="pending-body">
              <div class="pending-cards">
                <template
                  v-for="(bean, index) in me.pending"
                  :key="`${bean}-${index}`"
                >
                  <div
                    v-if="beanTypes[bean]"
                    class="pending-card"
                    draggable="true"
                    @dragstart="pickedPending = index"
                  >
                    <span
                      v-if="index === pendingIndex"
                      class="now"
                    >Planting</span>
                    <button
                      class="card-button"
                      :aria-pressed="index === pendingIndex"
                      :aria-label="`Plant the ${beanTypes[bean]!.name} bean next`"
                      @click="pickedPending = index"
                    >
                      <BeanCard
                        :bean="beanTypes[bean]!"
                        size="small"
                        :selected="index === pendingIndex"
                      />
                    </button>
                  </div>
                </template>
              </div>
              <p class="pending-hint">
                {{ pendingHint }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div
        v-if="offer"
        class="offer-spot"
      >
        <OfferCard
          :offer="offer"
          :from-name="nameOf(offer.from)"
          :avatar="avatarOf(offer.from)"
          :bean-types="beanTypes"
          :can-accept="canAcceptOffer"
          :busy="busy"
          @accept="move({ type: 'accept_offer' })"
          @decline="move({ type: 'decline_offer' })"
        />
      </div>
    </main>

    <section class="me">
      <PlayerHand
        :hand="hand"
        :bean-types="beanTypes"
        :can-plant-front="canPlantFromHand"
        :pickable="isTrading"
        :picked="trade.pickedHand.value"
        @pick="trade.toggleHand"
        @point="pointedBean = $event"
      />
    </section>

    <Transition name="peek">
      <div
        v-if="pointedType"
        class="preview"
        aria-hidden="true"
      >
        <BeanCard
          :bean="pointedType"
          size="full"
        />
        <p>{{ pointedCopies }} in your hand</p>
      </div>
    </Transition>

    <Transition name="slide">
      <div
        v-if="showLog"
        class="log-spot"
      >
        <GameLog
          :entries="game.log"
          :you="me?.name ?? 'You'"
          @close="showLog = false"
        />
      </div>
    </Transition>

    <div
      v-if="showPayouts"
      class="overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Bean payouts"
      @click.self="showPayouts = false"
    >
      <div class="panel payouts">
        <div class="payouts-header">
          <h2>Payouts</h2>
          <button
            class="small secondary"
            @click="showPayouts = false"
          >
            Close
          </button>
        </div>
        <p>Rarer beans pay more. The number under each coin stack is how many beans that payout needs.</p>
        <div class="payout-cards">
          <BeanCard
            v-for="bean in game.bean_types"
            :key="bean.key"
            :bean="bean"
            size="full"
          />
        </div>
      </div>
    </div>

    <Transition name="pop">
      <div
        v-if="game.over && !replaying"
        class="overlay"
        role="dialog"
        aria-modal="true"
        aria-labelledby="game-over-title"
      >
        <div class="panel result">
          <h2 id="game-over-title">
            {{ youWon ? "You win the bazaar!" : "Game over" }}
          </h2>
          <ol>
            <li
              v-for="(entry, place) in standings"
              :key="entry.index"
              :class="{ you: entry.index === you }"
            >
              <span class="place">{{ place + 1 }}</span>
              <span class="who">{{ entry.name }}</span>
              <span class="score">{{ coinText(entry.coins) }}</span>
            </li>
          </ol>
          <button
            class="big"
            @click="emit('leave')"
          >
            Play again
          </button>
        </div>
      </div>
    </Transition>

    <TutorialGuide
      v-if="showTutorial"
      @close="emit('tutorialDone')"
    />
  </div>
</template>

<style scoped>
/* The whole screen is the table: bots along the top, the market in the middle,
   your farm and hand along the bottom, with the hand running off the edge. */
/* Pinned to the window: a game table never scrolls. */
.game { position: fixed; inset: 0; display: grid; grid-template-columns: minmax(0, 1fr); grid-template-rows: auto minmax(520px, 1fr) auto; overflow: clip; }

.topbar { position: relative; z-index: 15; display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 10px 20px; }
.tools { display: flex; gap: 2px; }
/* Menu items, not game actions: plain text so the phase tracker leads the bar. */
.tool { background: none; border: 0; box-shadow: none; padding: 6px 10px; border-radius: 8px; color: #fff6dc; font-size: 14px; text-shadow: 0 1px 0 rgba(0, 0, 0, .45); }
.tool:hover { background: rgba(30, 14, 4, .25); }
.tool[aria-pressed="true"] { background: rgba(30, 14, 4, .35); }
.tool:focus-visible { outline: 3px solid var(--gold); outline-offset: 1px; }

.felt { position: relative; }
.felt :deep(.seat) { position: absolute; z-index: 2; }
/* Seats sit on an arc around the market: sides low on the edges, the rest along the top. */
.felt :deep(.spot-left) { left: 2.5%; top: 30%; }
.felt :deep(.spot-right) { right: 2.5%; top: 30%; }
.felt :deep(.spot-top) { left: 50%; top: 0; transform: translateX(-50%); }
.felt :deep(.spot-top-left) { left: 24%; top: 0; transform: translateX(-50%); }
.felt :deep(.spot-top-right) { right: 24%; top: 0; transform: translateX(50%); }
.middle { position: absolute; left: 50%; top: 42%; transform: translate(-50%, -50%); z-index: 1; }
.offer-spot { position: fixed; inset: 0; z-index: 25; display: grid; place-items: center; background: rgba(20, 10, 4, .45); }

.me { position: relative; z-index: 3; display: grid; gap: 6px; padding: 0 24px; }
.row { display: flex; gap: 28px; align-items: flex-end; justify-content: center; }
.my-spot { position: absolute; left: 50%; bottom: 8px; transform: translateX(-50%); z-index: 2; }
.farm { display: flex; gap: 10px; align-items: flex-end; }
.buy-field {
  width: 110px;
  min-height: 190px;
  border-radius: 14px;
  border: 2px dashed #fff6dc;
  background: rgba(255, 246, 220, .12);
  color: #fff6dc;
  box-shadow: none;
  font-size: 14px;
}
.action { width: 320px; display: grid; gap: 10px; align-content: end; justify-items: start; }
.plate-row { display: flex; gap: 8px; align-items: center; }
.my-plate {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 16px 4px 4px;
  border-radius: 999px;
  background: rgba(255, 246, 220, .95);
  color: var(--ink);
  box-shadow: 0 6px 14px rgba(0, 0, 0, .3);
  transition: box-shadow .25s ease;
}
.my-plate.active { box-shadow: 0 0 0 4px var(--gold), 0 0 26px rgba(246, 201, 56, .7); }
.my-plate img { width: 40px; height: 40px; }
.my-plate strong { font-family: "Fraunces", serif; font-size: 18px; }
.my-plate span { font-weight: 800; color: var(--gold-dark); }
.instruction {
  margin: 0;
  display: flex;
  gap: 10px;
  align-items: center;
  background: rgba(255, 246, 220, .95);
  color: var(--ink);
  border-radius: 999px;
  padding: 9px 16px;
  font-weight: 800;
  line-height: 1.3;
  box-shadow: 0 6px 16px rgba(0, 0, 0, .3);
}
.instruction.thinking { color: var(--muted); }
.spinner { flex: none; width: 16px; height: 16px; border-radius: 50%; border: 3px solid var(--panel-dark); border-top-color: var(--accent); animation: spin .7s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.buttons { display: flex; gap: 8px; }
button.big { font-size: 17px; padding: 9px 22px; }
.pending { width: 430px; display: grid; gap: 8px; padding: 12px 14px; box-shadow: 0 0 0 4px var(--gold), 0 10px 24px rgba(0, 0, 0, .4); }
.pending-head { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.pending-head strong { font-family: "Fraunces", serif; font-size: 17px; }
.left { flex: none; padding: 1px 10px; border-radius: 999px; background: var(--accent); color: #fff; font-size: 12px; font-weight: 800; }
.pending-rule { margin: 0; font-size: 12px; color: var(--muted); }
.pending-body { display: flex; gap: 14px; align-items: center; }
.pending-cards { flex: none; max-width: 290px; display: flex; flex-wrap: wrap; gap: 8px; padding: 12px 0 10px; }
.pending-card { position: relative; cursor: grab; }
.now {
  position: absolute;
  bottom: -10px;
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
.pending-hint { flex: 1; margin: 0; font-size: 13px; font-weight: 800; }
.locked {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
  padding: 6px 10px;
  border-radius: 10px;
  background: rgba(255, 246, 220, .95);
  color: var(--ink);
  font-size: 12px;
  font-weight: 800;
  box-shadow: 0 6px 14px rgba(0, 0, 0, .3);
}

.preview {
  position: fixed;
  right: 20px;
  bottom: 20px;
  z-index: 70;
  display: grid;
  justify-items: center;
  gap: 6px;
  pointer-events: none;
}
.preview p { margin: 0; color: var(--ink); padding: 2px 10px; border-radius: 999px; background: var(--panel); border: 2px solid var(--ink); font-size: 12px; font-weight: 800; }
.peek-enter-active, .peek-leave-active { transition: opacity .15s ease, transform .15s ease; }
.peek-enter-from, .peek-leave-to { opacity: 0; transform: translateY(12px); }
.log-spot { position: fixed; right: 16px; top: 60px; z-index: 20; }
.overlay { position: fixed; inset: 0; z-index: 30; display: grid; place-items: center; padding: 16px; background: rgba(20, 14, 10, .72); }
.payouts { width: min(980px, 100%); max-height: 90vh; overflow-y: auto; display: grid; gap: 12px; padding: 20px; }
.payouts-header { display: flex; justify-content: space-between; align-items: center; }
.payouts p { margin: 0; }
.payout-cards { display: flex; flex-wrap: wrap; gap: 12px; justify-content: center; }
.result { width: min(420px, 100%); display: grid; gap: 16px; padding: 24px; text-align: center; }
.result h2 { font-size: 30px; }
.result ol { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
.result li { display: grid; grid-template-columns: 32px 1fr auto; align-items: center; gap: 10px; padding: 8px 12px; border-radius: 10px; background: var(--panel-dark); text-align: left; }
.result li:first-child { background: var(--gold); }
.result li.you .who { font-weight: 800; }
.place { font-family: "Fraunces", serif; font-weight: 900; font-size: 20px; }
.score { font-weight: 800; }
.result button { justify-self: center; }

.slide-enter-active, .slide-leave-active { transition: all .2s ease; }
.slide-enter-from, .slide-leave-to { opacity: 0; transform: translateX(20px); }
.pop-enter-active, .pop-leave-active { transition: opacity .25s ease; }
.pop-enter-from, .pop-leave-to { opacity: 0; }
</style>
