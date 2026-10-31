<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue"
import BeanCard from "./components/BeanCard.vue"
import BeanField from "./components/BeanField.vue"
import GameLog from "./components/GameLog.vue"
import OpponentPanel from "./components/OpponentPanel.vue"
import PhaseTracker from "./components/PhaseTracker.vue"
import TradePanel from "./components/TradePanel.vue"
import { useGame } from "./useGame"
import type { BeanKey, BeanType, FieldState, TradeOffer } from "./types"

const MAX_HAND_PLANTS = 2
const MAX_FIELDS = 3
const THIRD_FIELD_PRICE = 3
const MAX_RUN_OUTS = 3

const { game, error, busy, start, move, resume, leave } = useGame()
const botCount = ref(3)
const pickedPending = ref<number | null>(null)

onMounted(resume)

const beanTypes = computed<Record<string, BeanType>>(() =>
  Object.fromEntries((game.value?.bean_types ?? []).map((bean) => [ bean.key, bean ])),
)
const me = computed(() => (game.value ? game.value.players[game.value.you] ?? null : null))
const hand = computed<BeanKey[]>(() => me.value?.hand ?? [])
const frontCard = computed(() => hand.value[0] ?? null)
const myTurn = computed(() => game.value !== null && !game.value.over && game.value.active_index === game.value.you)
const phase = computed(() => game.value?.phase ?? null)
const activeName = computed(() => game.value?.players[game.value.active_index]?.name ?? "")

const canPlantFromHand = computed(() =>
  myTurn.value && phase.value === "plant" && (game.value?.hand_plants ?? 0) < MAX_HAND_PLANTS && frontCard.value !== null,
)
const canFlip = computed(() =>
  myTurn.value && phase.value === "plant" && ((game.value?.hand_plants ?? 0) > 0 || hand.value.length === 0),
)
const pendingIndex = computed(() => {
  const pending = me.value?.pending ?? []
  if (phase.value !== "plant_pending" || pending.length === 0) return null
  return pickedPending.value !== null && pickedPending.value < pending.length ? pickedPending.value : 0
})
const pendingCard = computed(() => (pendingIndex.value === null ? null : me.value?.pending[pendingIndex.value] ?? null))
const canBuyField = computed(() =>
  !!me.value && !game.value?.over && me.value.fields.length < MAX_FIELDS && me.value.coins >= THIRD_FIELD_PRICE,
)
const partners = computed(() =>
  (game.value?.players ?? [])
    .map((player, index) => ({ index, name: player.name }))
    .filter((partner) => partner.index !== game.value?.you),
)
const standings = computed(() =>
  (game.value?.players ?? [])
    .map((player, index) => ({ index, name: player.name, coins: player.coins }))
    .sort((left, right) => right.coins - left.coins),
)
const youWon = computed(() => !!game.value?.winners.includes(game.value.you))
const turnLabel = computed(() => {
  if (game.value?.over) return "Game over"
  return myTurn.value ? "Your turn" : `${activeName.value}'s turn`
})

watch(() => me.value?.pending.length, () => { pickedPending.value = null })

// One clear instruction for what to do right now.
const instruction = computed(() => {
  const current = game.value
  if (!current || current.over) return ""
  if (pendingCard.value) return "Plant the cards you traded for or kept: pick a card, then press Plant on a field."
  if (!myTurn.value) return `${activeName.value} is playing...`
  if (current.phase === "plant" && current.hand_plants === 0) {
    const card = frontCard.value
    if (!card) return "Your hand is empty, so flip 2 cards."
    if (!me.value?.fields.some((field) => accepts(field, card))) {
      return `No field can take your ${beanName(card)}: harvest a field first, then plant it.`
    }
    return "Plant the front card of your hand (outlined in red) into a field."
  }
  if (current.phase === "plant") return "Plant your next card too, or flip 2 cards to start trading."
  return "Offer the face-up cards and your hand to the bots, then press Done trading."
})

function coinText(coins: number): string {
  return `${coins} ${coins === 1 ? "coin" : "coins"}`
}

function beanName(bean: BeanKey): string {
  return beanTypes.value[bean]?.name ?? bean
}

function accepts(field: FieldState, bean: BeanKey): boolean {
  return field.bean === null || field.bean === bean
}

function plantLabel(field: FieldState): string | null {
  if (busy.value) return null
  if (canPlantFromHand.value && frontCard.value && accepts(field, frontCard.value)) return `Plant ${beanName(frontCard.value)}`
  if (pendingCard.value && accepts(field, pendingCard.value)) return `Plant ${beanName(pendingCard.value)}`
  return null
}

// A lone bean is protected while another of your fields has more than one.
function canHarvest(field: FieldState): boolean {
  if (busy.value || !me.value || game.value?.over || field.count === 0) return false
  return field.count > 1 || !me.value.fields.some((other) => other.count > 1)
}

function plantInto(fieldIndex: number): void {
  if (canPlantFromHand.value) {
    move({ type: "plant_from_hand", field_index: fieldIndex })
  } else if (pendingIndex.value !== null) {
    move({ type: "plant_pending", pending_index: pendingIndex.value, field_index: fieldIndex })
  }
}

function trade(offer: TradeOffer): void {
  move({ type: "trade", ...offer })
}
</script>

<template>
  <div class="app">
    <header>
      <h1>Bean Bazaar</h1>
      <PhaseTracker
        v-if="game"
        :phase="game.phase"
        :turn-label="turnLabel"
      />
      <button
        v-if="game"
        class="small secondary"
        @click="leave"
      >
        New game
      </button>
    </header>

    <Transition name="deal">
      <p
        v-if="error"
        class="error"
        role="alert"
      >
        {{ error }}
        <button
          class="small secondary"
          aria-label="Dismiss"
          @click="error = null"
        >
          OK
        </button>
      </p>
    </Transition>

    <!-- Start screen -->
    <section
      v-if="!game"
      class="start"
    >
      <div class="fan">
        <img
          v-for="bean in ['blue', 'chili', 'stink', 'green', 'soy']"
          :key="bean"
          :src="`/cards/${bean}.webp`"
          alt=""
        >
      </div>
      <div class="panel intro">
        <h2>Plant, trade and harvest your way to the most coins.</h2>
        <p>
          Plant the front card of your hand, trade the two face-up cards with the bots, and harvest
          your fields for coins before the deck runs out for the third time.
        </p>
        <div class="bots">
          <span>Play against</span>
          <button
            v-for="count in [2, 3, 4]"
            :key="count"
            :class="count === botCount ? '' : 'secondary'"
            :aria-pressed="count === botCount"
            @click="botCount = count"
          >
            {{ count }} bots
          </button>
        </div>
        <button
          class="big"
          :disabled="busy"
          @click="start(botCount)"
        >
          {{ busy ? "Dealing..." : "Start game" }}
        </button>
      </div>
    </section>

    <!-- Game table -->
    <template v-else-if="me">
      <section class="seats">
        <template
          v-for="(player, index) in game.players"
          :key="index"
        >
          <OpponentPanel
            v-if="index !== game.you"
            :player="player"
            :bean-types="beanTypes"
            :active="index === game.active_index && !game.over"
            :winner="game.winners.includes(index)"
          />
        </template>
      </section>

      <section class="middle">
        <div class="market">
          <div class="piles">
            <div class="pile">
              <div class="stack">
                <img
                  src="/cards/coin_back.webp"
                  alt=""
                >
              </div>
              <span>Deck <strong>{{ game.deck.draw }}</strong></span>
            </div>
            <div class="pile">
              <div class="stack discard">
                <img
                  v-if="game.deck.discard"
                  src="/cards/coin_back.webp"
                  alt=""
                >
              </div>
              <span>Discard <strong>{{ game.deck.discard }}</strong></span>
            </div>
            <div class="reshuffles">
              Reshuffles
              <span
                v-for="run in MAX_RUN_OUTS"
                :key="run"
                class="pip"
                :class="{ used: run <= game.deck.run_outs }"
              />
            </div>
          </div>

          <div
            v-if="busy || instruction"
            class="instruction"
            :class="{ thinking: busy }"
          >
            <span
              v-if="busy"
              class="spinner"
              aria-hidden="true"
            />
            {{ busy ? "Thinking..." : instruction }}
          </div>

          <TradePanel
            v-if="myTurn && phase === 'trade'"
            :face-up="game.face_up"
            :hand="hand"
            :partners="partners"
            :bean-types="beanTypes"
            :busy="busy"
            @trade="trade"
            @done="move({ type: 'end_trading' })"
          />
          <div
            v-else-if="game.face_up.length"
            class="face-up"
          >
            <h3>Face-up cards</h3>
            <TransitionGroup
              name="deal"
              tag="div"
              class="row"
            >
              <template
                v-for="(bean, index) in game.face_up"
                :key="`${bean}-${index}`"
              >
                <BeanCard
                  v-if="beanTypes[bean]"
                  :bean="beanTypes[bean]"
                />
              </template>
            </TransitionGroup>
          </div>
        </div>

        <GameLog
          :entries="game.log"
          you="You"
        />
      </section>

      <section class="me">
        <div class="me-header">
          <h2>Your farm</h2>
          <span class="coins">{{ coinText(me.coins) }}</span>
          <button
            v-if="canBuyField"
            class="small"
            :disabled="busy"
            @click="move({ type: 'buy_third_field' })"
          >
            Buy 3rd field ({{ THIRD_FIELD_PRICE }} coins)
          </button>
        </div>

        <div class="farm">
          <div class="fields">
            <BeanField
              v-for="(field, index) in me.fields"
              :key="index"
              :field="field"
              :bean-type="field.bean ? beanTypes[field.bean] ?? null : null"
              :plant-label="plantLabel(field)"
              :can-harvest="canHarvest(field)"
              @plant="plantInto(index)"
              @harvest="move({ type: 'harvest', field_index: index })"
            />
          </div>

          <div
            v-if="me.pending.length"
            class="pending"
          >
            <h3>To plant now</h3>
            <TransitionGroup
              name="deal"
              tag="div"
              class="row"
            >
              <template
                v-for="(bean, index) in me.pending"
                :key="`${bean}-${index}`"
              >
                <button
                  v-if="beanTypes[bean]"
                  class="card-button"
                  :aria-pressed="index === pendingIndex"
                  @click="pickedPending = index"
                >
                  <BeanCard
                    :bean="beanTypes[bean]"
                    :selected="index === pendingIndex"
                  />
                </button>
              </template>
            </TransitionGroup>
          </div>
        </div>

        <div class="hand-area">
          <div class="hand-header">
            <h3>Your hand</h3>
            <span class="muted">Front on the left. The order never changes; new cards go to the back.</span>
            <button
              v-if="canFlip"
              :disabled="busy"
              @click="move({ type: 'flip_cards' })"
            >
              Flip 2 cards
            </button>
          </div>
          <TransitionGroup
            name="deal"
            tag="div"
            class="hand"
          >
            <template
              v-for="(bean, index) in hand"
              :key="`${bean}-${hand.length - index}`"
            >
              <div
                v-if="beanTypes[bean]"
                class="hand-card"
              >
                <span
                  v-if="index === 0"
                  class="next"
                >Next</span>
                <BeanCard
                  :bean="beanTypes[bean]"
                  :highlighted="index === 0 && canPlantFromHand"
                />
              </div>
            </template>
          </TransitionGroup>
          <span
            v-if="!hand.length"
            class="muted"
          >No cards in hand</span>
        </div>
      </section>

      <details class="guide">
        <summary>Bean guide: copies in the deck and coin payouts</summary>
        <div class="row">
          <BeanCard
            v-for="bean in game.bean_types"
            :key="bean.key"
            :bean="bean"
            size="full"
          />
        </div>
      </details>

      <!-- Final standings -->
      <Transition name="deal">
        <div
          v-if="game.over"
          class="overlay"
          role="dialog"
          aria-modal="true"
          aria-labelledby="game-over-title"
        >
          <div class="panel result">
            <h2 id="game-over-title">
              {{ youWon ? "You win!" : "Game over" }}
            </h2>
            <ol>
              <li
                v-for="(entry, place) in standings"
                :key="entry.index"
                :class="{ you: entry.index === game.you }"
              >
                <span class="place">{{ place + 1 }}</span>
                <span class="who">{{ entry.name }}</span>
                <span class="score">{{ coinText(entry.coins) }}</span>
              </li>
            </ol>
            <button
              class="big"
              @click="leave"
            >
              Play again
            </button>
          </div>
        </div>
      </Transition>
    </template>
  </div>
</template>

<style scoped>
.app { max-width: 1240px; margin: 0 auto; padding: 18px 16px 60px; display: grid; gap: 16px; }

header { display: flex; justify-content: space-between; align-items: center; gap: 16px; flex-wrap: wrap; }
h1 { color: var(--gold); font-size: 34px; -webkit-text-stroke: 1px var(--ink); }
button.big { font-size: 18px; padding: 10px 26px; justify-self: start; }

.error {
  margin: 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  background: var(--accent);
  color: #fff;
  border: 2px solid var(--ink);
  border-radius: 10px;
  padding: 8px 12px;
  font-weight: 700;
}

/* Start screen */
.start { display: flex; gap: 40px; align-items: center; justify-content: center; flex-wrap: wrap; padding: 40px 0; }
.fan { position: relative; width: 300px; height: 260px; }
.fan img {
  position: absolute;
  left: 90px;
  top: 20px;
  width: 130px;
  border-radius: 10px;
  border: 4px solid #fff;
  box-shadow: 0 10px 20px -10px rgba(0, 0, 0, .8);
  transform-origin: 50% 120%;
}
.fan img:nth-child(1) { transform: rotate(-24deg); }
.fan img:nth-child(2) { transform: rotate(-12deg); }
.fan img:nth-child(3) { transform: rotate(0deg); }
.fan img:nth-child(4) { transform: rotate(12deg); }
.fan img:nth-child(5) { transform: rotate(24deg); }
.intro { max-width: 460px; display: grid; gap: 14px; padding: 22px; }
.intro p { margin: 0; line-height: 1.5; }
.bots { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }

/* Table */
.seats { display: flex; gap: 12px; flex-wrap: wrap; }

.middle { display: grid; grid-template-columns: 1fr 280px; gap: 16px; align-items: start; }
.market {
  display: grid;
  gap: 14px;
  padding: 16px;
  border-radius: 16px;
  background: radial-gradient(circle at 50% 30%, #4a6b3a, #2e4a26);
  border: 3px solid #1f3319;
  box-shadow: inset 0 0 40px rgba(0, 0, 0, .35);
}
.piles { display: flex; gap: 22px; align-items: center; flex-wrap: wrap; }
.pile { display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: 13px; }
.stack {
  width: 58px;
  aspect-ratio: 63 / 88;
  border-radius: 7px;
  border: 2px dashed rgba(246, 239, 227, .35);
  box-shadow: 3px -3px 0 -1px #fff, 6px -6px 0 -2px #fff;
}
.stack.discard { box-shadow: none; }
.stack img { width: 100%; height: 100%; object-fit: cover; border-radius: 5px; display: block; }
.reshuffles { display: flex; align-items: center; gap: 6px; font-size: 13px; }
.pip { width: 12px; height: 12px; border-radius: 50%; border: 2px solid var(--panel); }
.pip.used { background: var(--accent); }

.instruction {
  display: flex;
  align-items: center;
  gap: 10px;
  background: var(--panel);
  color: var(--ink);
  border: 2px solid var(--ink);
  border-radius: 10px;
  padding: 10px 14px;
  font-weight: 800;
}
.instruction.thinking { color: var(--muted); }
.spinner {
  width: 16px;
  height: 16px;
  border-radius: 50%;
  border: 3px solid var(--panel-dark);
  border-top-color: var(--accent);
  animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

.face-up, .pending { display: grid; gap: 8px; }
.row { display: flex; gap: 10px; flex-wrap: wrap; align-items: flex-end; }

/* Your area */
.me { display: grid; gap: 16px; padding: 16px; border-radius: 16px; background: rgba(0, 0, 0, .22); }
.me-header { display: flex; gap: 14px; align-items: baseline; flex-wrap: wrap; }
.coins { font-weight: 800; color: var(--gold); font-size: 18px; }
.farm { display: flex; gap: 24px; flex-wrap: wrap; align-items: flex-start; }
.fields { display: flex; gap: 12px; flex-wrap: wrap; }

.hand-area { display: grid; gap: 10px; }
.hand-header { display: flex; gap: 12px; align-items: baseline; flex-wrap: wrap; }
.hand { display: flex; padding: 14px 0 4px 6px; flex-wrap: wrap; row-gap: 14px; }
.hand-card { position: relative; margin-right: -10px; transition: transform .15s ease; }
.hand-card:hover { transform: translateY(-12px); z-index: 2; }
.next {
  position: absolute;
  top: -12px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 3;
  background: var(--accent);
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  padding: 1px 8px;
  border-radius: 999px;
  border: 2px solid var(--ink);
}
.muted { font-size: 13px; font-weight: 500; color: rgba(246, 239, 227, .6); }

.guide summary { cursor: pointer; font-weight: 800; margin-bottom: 10px; }

/* Game over */
.overlay {
  position: fixed;
  inset: 0;
  z-index: 10;
  display: grid;
  place-items: center;
  padding: 16px;
  background: rgba(20, 14, 10, .7);
}
.result { width: min(420px, 100%); display: grid; gap: 16px; padding: 24px; text-align: center; }
.result h2 { font-size: 32px; }
.result ol { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
.result li {
  display: grid;
  grid-template-columns: 32px 1fr auto;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  border-radius: 10px;
  background: var(--panel-dark);
  text-align: left;
}
.result li:first-child { background: var(--gold); }
.result li.you .who { font-weight: 800; }
.place { font-family: "Fraunces", serif; font-weight: 900; font-size: 20px; }
.score { font-weight: 800; }
.result button { justify-self: center; }

@media (max-width: 900px) {
  .middle { grid-template-columns: 1fr; }
}
</style>
