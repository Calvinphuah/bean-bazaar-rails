import { ref } from "vue"
import { loadGame, sendMove, startGame } from "./api"
import type { GameState, Move } from "./types"

const STORAGE_KEY = "bean-bazaar-game-id"

// localStorage can throw in private windows; resuming is only a convenience.
function savedId(): number | null {
  try {
    const value = Number(localStorage.getItem(STORAGE_KEY))
    return Number.isInteger(value) && value > 0 ? value : null
  } catch {
    return null
  }
}

function saveId(id: number | null): void {
  try {
    if (id === null) localStorage.removeItem(STORAGE_KEY)
    else localStorage.setItem(STORAGE_KEY, String(id))
  } catch {
    // Nothing to do: the game still works, it just won't resume after a reload.
  }
}

export function useGame() {
  const game = ref<GameState | null>(null)
  const error = ref<string | null>(null)
  const busy = ref(false)

  async function run(action: () => Promise<GameState>): Promise<void> {
    busy.value = true
    error.value = null
    try {
      game.value = await action()
      saveId(game.value.id)
    } catch (caught) {
      error.value = caught instanceof Error ? caught.message : String(caught)
    } finally {
      busy.value = false
    }
  }

  function start(botCount: number): Promise<void> {
    return run(() => startGame(botCount))
  }

  async function move(next: Move): Promise<void> {
    const current = game.value
    if (current === null) return
    await run(() => sendMove(current.id, next))
  }

  async function resume(): Promise<void> {
    const id = savedId()
    if (id === null) return
    await run(() => loadGame(id))
    if (game.value === null) {
      saveId(null)
      error.value = null
    }
  }

  function leave(): void {
    game.value = null
    error.value = null
    saveId(null)
  }

  return { game, error, busy, start, move, resume, leave }
}
