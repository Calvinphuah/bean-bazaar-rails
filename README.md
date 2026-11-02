# Bean Bazaar

A bean-trading card game for 1 player against 2 to 4 bots. Plant beans, trade with the table, and harvest your fields for coins. Whoever holds the most coins when the third season ends wins the bazaar.

## How to play

- **Plant.** Every turn you must plant the front card of your hand. You may plant the next card too. You can never reorder your hand.
- **Fields.** Each field grows one bean type. A third field costs 3 coins.
- **Harvest.** Bigger piles pay more coins. You can't harvest a field holding just 1 bean while another field has more.
- **Flip and trade.** After planting, flip 2 cards from the deck and trade them, or cards from your hand, with the bots. Whatever you get or keep must be planted.
- **Bot turns.** Bots offer you deals on their turns. You can take the deal, turn it down, or make your own offer.
- **Seasons.** Each time the deck runs out, a new season starts. The game ends when the third season's deck runs out.

Press **Rules** in the game for a guided tour. Bots come in three levels: Easy, Normal and Smart. Games with 4 bots add the Coffee and Golden beans.

## Running it locally

You need Ruby 3.4.8, Node 22, PostgreSQL and [overmind](https://github.com/DarthSim/overmind).

```bash
cd backend && bundle install && bin/rails db:prepare
```

```bash
cd frontend && npm install
```

```bash
bin/dev
```

Then open http://localhost:5173. `bin/dev` starts the Rails API on port 3000 and the Vite app on port 5173. Without overmind, run `bin/rails server` in `backend` and `npm run dev` in `frontend` in two terminals.

## How it's built

- `backend/lib/bean_bazaar`: the game engine and bots, in plain Ruby.
- `backend/app`: a Rails 8 JSON API that saves games and runs the bots' turns.
- `frontend`: a Vue 3 + TypeScript app built with Vite.

## Checks

```bash
cd backend && bundle exec rspec && bin/rubocop && bin/brakeman --no-pager
```

```bash
cd frontend && npm run typecheck && npm run lint
```

## Credits

- Sound effects: "Casino Audio" by [Kenney](https://www.kenney.nl), CC0.
- Card and character art made for this game.
