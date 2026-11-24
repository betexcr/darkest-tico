# Save fixtures (P3-08)

`save_v<N>.json` is a real save written by the game at save version N, used by
`tests/test_save_migration.gd` to check that today's `GameState.apply_save_data` still loads it.

Each was made from the commit that introduced that `SAVE_VERSION` (v14 was never released):

| Version | Commit |
|---:|---|
| 3 | 6e515c6 |
| 4 | 3a1e003 |
| 5 | d9211ac |
| 6 | 4a1bae8 |
| 7 | a7628e8 |
| 8 | b3aae06 |
| 9 | bec2c67 |
| 10 | b046d83 |
| 11 | 730a330 |
| 12 | 89beb59 |
| 13 | 7d4e898 |
| 15 | 8d76b96 |
| 16 | 0f7dc35 |
| 17 | e49c068 (v17 was introduced in 5ecacb9) |
| 18 | 214023d |

How (run once per version; the save holds colones 4321, week 6, the first hero at 37 stress
with a machete equipped, and some gallo pinto, where that version had those things):

    git worktree add --detach /tmp/old <commit>
    cp tools/dump_save.gd /tmp/old/dump_save.gd
    godot --headless --path /tmp/old --import
    godot --headless --path /tmp/old -s res://dump_save.gd -- tests/fixtures/save_v<N>.json
    git worktree remove --force /tmp/old

When you bump `SAVE_VERSION`, add the outgoing version's fixture the same way before you change
the save shape.
