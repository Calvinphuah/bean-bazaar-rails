import type { GameState, Move } from "./types"

async function request(path: string, init: RequestInit = {}): Promise<GameState> {
  const response = await fetch(`/api${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", Accept: "application/json" },
  })
  const body: unknown = await response.json().catch(() => null)
  // Every response is wrapped in a `game` root, success or error.
  const game = typeof body === "object" && body !== null && "game" in body ? body.game : null
  if (!response.ok) throw new Error(errorMessage(game, response.status))

  // The API is the only producer of this shape; trust it at this one boundary.
  return game as GameState
}

function errorMessage(game: unknown, status: number): string {
  if (typeof game === "object" && game !== null && "error_message" in game && typeof game.error_message === "string") {
    return game.error_message
  }
  return status === 404 ? "That game no longer exists" : "Something went wrong, please try again"
}

export function startGame(botCount: number): Promise<GameState> {
  return request("/games", { method: "POST", body: JSON.stringify({ bot_count: botCount }) })
}

export function loadGame(id: number): Promise<GameState> {
  return request(`/games/${id}`)
}

export function sendMove(id: number, move: Move): Promise<GameState> {
  return request(`/games/${id}/moves`, { method: "POST", body: JSON.stringify({ move }) })
}
