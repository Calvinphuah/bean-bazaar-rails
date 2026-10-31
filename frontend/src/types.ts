// Mirrors GameSerializer#as_json in the Rails API.
export type BeanKey = string

export type Phase = "plant" | "trade" | "plant_pending" | "over"

export interface BeanType {
  key: BeanKey
  name: string
  copies: number
  // Coins earned ("1".."4") mapped to the beans needed.
  meter: Record<string, number>
}

export interface FieldState {
  bean: BeanKey | null
  count: number
  coins: number
}

export interface PlayerState {
  name: string
  // Only your own hand is sent; bots' hands are null.
  hand: BeanKey[] | null
  hand_size: number
  fields: FieldState[]
  coins: number
  pending: BeanKey[]
}

export interface GameState {
  id: number
  you: number
  phase: Phase
  active_index: number
  hand_plants: number
  over: boolean
  winners: number[]
  deck: { draw: number; discard: number; run_outs: number }
  face_up: BeanKey[]
  players: PlayerState[]
  // Newest last; the server keeps the latest 40 entries.
  log: string[]
  bean_types: BeanType[]
}

export interface TradeOffer {
  partner_index: number
  face_up_indexes: number[]
  hand_indexes: number[]
  partner_beans: BeanKey[]
}

export type Move =
  | { type: "plant_from_hand"; field_index: number }
  | { type: "flip_cards" }
  | { type: "end_trading" }
  | { type: "buy_third_field" }
  | { type: "plant_pending"; pending_index: number; field_index: number }
  | { type: "harvest"; field_index: number }
  | ({ type: "trade" } & TradeOffer)
