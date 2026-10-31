import type { GameState, Move } from "./types"

async function request(path: string, init: RequestInit = {}): Promise<GameState> {
  const response = await fetch(`/api${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", Accept: "application/json" },
  })
  const body: unknown = await response.json().catch(() => null)
  if (!response.ok) throw new Error(errorMessage(body, response.status))

  // The API is the only producer of this shape; trust it at this one boundary.
  return body as GameState
}

function errorMessage(body: unknown, status: number): string {
  if (typeof body === "object" && body !== null && "error" in body && typeof body.error === "string") {
    return body.error
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
