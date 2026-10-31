<script setup lang="ts">
import { computed } from "vue"

const props = defineProps<{
  entries: string[]
  you: string
}>()

// Newest first, so the latest bot moves are visible without scrolling. The
// engine names every seat the same way, so "You's turn" is reworded here.
const newestFirst = computed(() =>
  [ ...props.entries ].reverse().map((entry) => (entry === `${props.you}'s turn` ? "Your turn" : entry)),
)

function isTurnChange(entry: string): boolean {
  return entry.endsWith("'s turn") || entry === "Your turn" || entry.includes("Game over")
}
</script>

<template>
  <aside class="panel log">
    <h3>Game log</h3>
    <ol aria-live="polite">
      <li
        v-for="(entry, index) in newestFirst"
        :key="entries.length - index"
        :class="{ turn: isTurnChange(entry), mine: entry.startsWith(you) || entry === 'Your turn' }"
      >
        {{ entry }}
      </li>
      <li
        v-if="!entries.length"
        class="muted"
      >
        Moves will appear here.
      </li>
    </ol>
  </aside>
</template>

<style scoped>
.log { display: flex; flex-direction: column; gap: 8px; max-height: 520px; }
ol { list-style: none; margin: 0; padding: 0; overflow-y: auto; display: grid; gap: 4px; font-size: 13px; }
li { padding: 3px 6px; border-radius: 6px; line-height: 1.35; }
li.turn { font-weight: 800; background: var(--panel-dark); margin-top: 6px; }
li.mine { color: var(--accent); font-weight: 700; }
.muted { color: var(--muted); }
</style>
