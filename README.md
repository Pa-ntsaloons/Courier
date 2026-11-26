# Courier

A lightweight World of Warcraft addon that adds a **Contacts** button to the mailbox, so you can address mail to your alts, friends, guildmates and recent recipients in one click.

Built for **WoW Forever**, and it also works on Retail.

## Features

- **Contacts button** next to the "To:" box on the Send Mail tab
- **Alts**: your characters on the same faction and ruleset (or connected realms on Retail)
- **Recent**: the last 20 people you mailed, tagged as Alt, Friend, Battle.net or Guild
- **Friends**: your in-game friends list, online first
- **Battle.net**: Battle.net friends currently online in the same game, faction and ruleset
- **Guild**: your guild roster
- **Inbox gold**: the total gold waiting in your inbox. Hover it to split it into auction sales, auction refunds, gold from players (listed by sender) and other mail, plus any COD you'd have to pay
- Class icons and class colours throughout
- Supports WoW Forever's region-wide names with surnames and its rulesets (PvP, RP-PvP and so on)
- **Syndicator integration**: if [Syndicator](https://www.curseforge.com/wow/addons/syndicator) is installed, every character it knows about shows up as an alt, without logging each one in first

Courier only adds a contacts button and a gold total. It doesn't replace the mailbox, so it works alongside other mail addons.

## Installation

1. Download the latest release.
2. Extract the `Courier` folder into:
   - WoW Forever: `World of Warcraft\_forever_\Interface\AddOns\`
   - Retail: `World of Warcraft\_retail_\Interface\AddOns\`
3. Make sure the folder is named `Courier`, then restart the game or type `/reload`.

## Usage

Open a mailbox, go to **Send Mail**, and click the contacts icon to the right of the "To:" box. Pick a name to fill in the recipient.

Without Syndicator, alts appear once you've logged into each one with Courier enabled.

### Slash commands

| Command | What it does |
|---|---|
| `/courier alts` | List every character Courier knows about |
| `/courier forget Name-Realm` | Remove a deleted or renamed character |
| `/courier clearrecent` | Clear the Recent list |
| `/courier debug` | Print what the friend and Battle.net APIs return (for bug reports) |

## Building a release

Update `## Version:` in `Courier.toc`, add a matching `## <version>` section at the top of `CHANGELOG.md`, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

This creates `releases\Courier-<version>.zip`, ready to upload to CurseForge, and copies that version's changelog to the clipboard for the upload form.

## Reporting bugs

Please open an issue that includes the output of `/courier debug` and any Lua error text.

## License

[MIT](LICENSE)
