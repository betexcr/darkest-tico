# Implementation notes (runtime tuning)

## Luz / Oscuridad (slice 1)

- **Decay:** Each move between nodes reduces `mission_light` by `light_decay_per_move` from the active region JSON (default **5** per step in [data/regions/sotanos.json](data/regions/sotanos.json)).
- **Low-light stress:** After a move, if `mission_light` is **below** `low_light_threshold` (default **40**), **one random living hero** gains `low_light_stress` (default **3**) stress, clamped to `stress_max`.
- Source of truth for intent: [01-core-systems-spec.md](01-core-systems-spec.md) (expedition / pressure meter).
