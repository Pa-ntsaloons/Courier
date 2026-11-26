# Courier

**Your mailbox's address book.** Courier adds a single **Contacts** button next to the "To:" box, so you can mail your alts, friends and guildmates in one click instead of typing names.

Built for **WoW Forever**, and it also works on Retail.

---

## Features

- **Alts**: every character you own on your current faction and ruleset
- **Recent**: the last 20 people you mailed, tagged **Alt**, **Friend**, **Battle.net** or **Guild** so you know who's who
- **Friends**: your in-game friends list, online first
- **Battle.net**: Battle.net friends who are online in the same game, faction and ruleset, shown with their BattleTag
- **Guild**: your full guild roster (scrollable)
- **Inbox gold**: see how much gold is waiting in your inbox. Hover it for a breakdown of auction sales, auction refunds, gold from players (by sender) and everything else, plus any COD you'd owe
- **Class icons and class colours** everywhere
- **Built for WoW Forever**: understands region-wide names with surnames, and only shows people on your ruleset (Normal, PvP, RP-PvP...)

## Syndicator integration

If you use **Syndicator** (Baganator's data addon), Courier picks up every character it already knows about. Your alts show up straight away, without logging each one in first.

Syndicator is **optional**. Without it, alts appear once you've logged into each one with Courier enabled.

## Lightweight and compatible

Courier doesn't replace the mailbox. It adds a contacts button and a gold total and nothing else, so it works alongside other mail addons, bag addons and UI packs.

---

## How to use

1. Open any mailbox and go to the **Send Mail** tab.
2. Click the **contacts icon** to the right of the "To:" box.
3. Pick a name. The recipient is filled in and the cursor jumps to the Subject box.

## Slash commands

| Command | What it does |
|---|---|
| `/courier alts` | List every character Courier knows about |
| `/courier forget Name-Realm` | Remove a deleted or renamed character |
| `/courier clearrecent` | Clear the Recent list |
| `/courier debug` | Print friend and Battle.net info (handy for bug reports) |

---

## Bugs and suggestions

Please report issues on [GitHub](https://github.com/Pa-ntsaloons/Courier/issues). Include the output of `/courier debug` and any Lua error text.
