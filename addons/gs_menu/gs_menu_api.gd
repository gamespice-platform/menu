extends RefCounted

## GameSpice Menu's API level. The rule for bumping it is on [GSAddonApi].
## LEVEL rises by one for anything a game could call that did not exist before. OLDEST is
## raised to LEVEL when something a game could have called is removed or changes meaning.

# What each level added: docs/api-levels.md.
const LEVEL := 24
const OLDEST := 1
