import { ref, watch } from "vue"
import type { GameState, LogEvent } from "./types"

const SETTINGS_KEY = "bean-bazaar-sound"
// Quiet by design: sounds mark moments, music sits under the table.
const SOUND_VOLUME = 0.45
// Bots' moves are heard, but softer than your own.
const BOT_VOLUME_SCALE = 0.5
const MUSIC_VOLUME = 0.15
const MUSIC_FADE_MS = 2500
// A fast replay can fire the same sound in a burst; one per gap is enough.
const MIN_GAP_MS = 140
// A harvest this big gets the fuller chip sound.
const BIG_HARVEST_COINS = 3

export type SoundName =
  | "plant-1" | "plant-2" | "flip" | "trade" | "harvest-small" | "harvest-big"
  | "offer" | "your-turn" | "buy-field" | "deal"

interface Settings {
  music: boolean
  sound: boolean
}

// localStorage can throw in private windows; sound settings are only a convenience.
function loadSettings(): Settings {
  try {
    const saved = JSON.parse(localStorage.getItem(SETTINGS_KEY) ?? "{}") as Partial<Settings>
    return { music: saved.music ?? true, sound: saved.sound ?? true }
  } catch {
    return { music: true, sound: true }
  }
}

function saveSettings(settings: Settings): void {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings))
  } catch {
    // Nothing to do: the settings just won't be remembered.
  }
}

// Sound effects for table moments and a soft music loop, both switchable.
// Browsers block audio until the first click or key press, so music waits for it.
export function useSound() {
  const settings = loadSettings()
  const musicOn = ref(settings.music)
  const soundOn = ref(settings.sound)
  const lastPlayed = new Map<SoundName, number>()
  let plantTurn = 0
  let music: HTMLAudioElement | null = null
  let fadeTimer: ReturnType<typeof setInterval> | null = null
  let unlocked = false

  function play(name: SoundName, quiet = false): void {
    if (!soundOn.value) return
    const now = performance.now()
    if (now - (lastPlayed.get(name) ?? -Infinity) < MIN_GAP_MS) return
    lastPlayed.set(name, now)

    const audio = new Audio(`/sounds/${name}.mp3`)
    audio.volume = SOUND_VOLUME * (quiet ? BOT_VOLUME_SCALE : 1)
    // A blocked or missing sound must never break the game.
    audio.play().catch(() => {})
  }

  // The sound for one replayed log event, if it deserves one.
  function cue(event: LogEvent | null, game: GameState | null): void {
    if (!event || !game) return
    const mine = event.player === game.you
    const quiet = !mine
    switch (event.type) {
      case "plant":
        play(++plantTurn % 2 ? "plant-1" : "plant-2", quiet)
        break
      case "flip":
        play("flip", quiet)
        break
      case "trade":
        play("trade", quiet)
        break
      case "harvest":
        play(harvestedCoins(event) >= BIG_HARVEST_COINS ? "harvest-big" : "harvest-small", quiet)
        break
      case "final_harvest":
        play("harvest-big", quiet)
        break
      case "buy_field":
        play("buy-field", quiet)
        break
      case "offer":
        if (game.offer) play("offer")
        break
      case "turn":
        if (mine) play("your-turn")
        break
    }
  }

  // The log says "... for 2 coins"; a harvest for nothing is still a small one.
  function harvestedCoins(event: LogEvent): number {
    return Number(/for (\d+) coin/.exec(event.text)?.[1] ?? 0)
  }

  function startMusic(): void {
    if (!musicOn.value || !unlocked) return
    if (!music) {
      music = new Audio()
      music.src = music.canPlayType('audio/webm; codecs="opus"') ? "/sounds/music.webm" : "/sounds/music.mp3"
      music.loop = true
    }
    music.volume = 0
    music.play().catch(() => {})
    fadeTo(MUSIC_VOLUME)
  }

  function stopMusic(): void {
    if (music) fadeTo(0, () => music?.pause())
  }

  function fadeTo(target: number, done?: () => void): void {
    if (fadeTimer) clearInterval(fadeTimer)
    const steps = 25
    const step = (target - (music?.volume ?? 0)) / steps
    let left = steps
    fadeTimer = setInterval(() => {
      if (!music) return
      left -= 1
      music.volume = left <= 0 ? target : Math.min(1, Math.max(0, music.volume + step))
      if (left <= 0 && fadeTimer) {
        clearInterval(fadeTimer)
        fadeTimer = null
        done?.()
      }
    }, MUSIC_FADE_MS / steps)
  }

  function unlock(): void {
    unlocked = true
    startMusic()
  }
  window.addEventListener("pointerdown", unlock, { once: true })
  window.addEventListener("keydown", unlock, { once: true })

  watch([musicOn, soundOn], ([musicNow, soundNow]) => {
    saveSettings({ music: musicNow, sound: soundNow })
    if (musicNow) startMusic()
    else stopMusic()
  })

  return {
    musicOn,
    soundOn,
    play,
    cue,
    toggleMusic: () => { musicOn.value = !musicOn.value },
    toggleSound: () => { soundOn.value = !soundOn.value },
  }
}
