# Preset base

`PRESET_BASE: 'gnosis'`.

Lighthouse (and most consensus clients) do not allow overriding preset values
from a config file — the preset is compiled in. JOC produces a block every 5
seconds on the execution layer, matching Gnosis Chain rather than Ethereum
mainnet's 12s, so the Gnosis preset is the right base.

References:

- https://github.com/gnosischain/specs/tree/master/consensus/preset/gnosis
- https://github.com/sigp/lighthouse/tree/stable/consensus/types/presets/gnosis
