# Production Roadmap (Preproduction to Post-Launch)

This roadmap translates the design package into production milestones with clear exit criteria.

## 0) Team Model Assumption

- Design: 1-2
- Engineering: 3-5
- Art/Animation: 3-6
- Audio/Narrative: 1-3
- Production/QA: 1-3

Adjust timeline linearly if staffing differs.

## 1) Phase 1 - Preproduction (8-12 Weeks)

## Goals

- Lock game vision, combat math baseline, and content bible.
- Build paper prototype and combat sandbox.

## Deliverables

- Complete GDD v1 package from `docs/01` through `docs/05`.
- Combat simulation sheet and stat curves.
- Narrative tone guide for satirical folkloric voice.
- Technical architecture doc:
  - Save system
  - Encounter generator
  - Status effect engine

## Exit Criteria

- Combat prototype validates:
  - rank system
  - stress breakpoints
  - mission pacing for short runs
- Core loop approved by stakeholders.

## 2) Phase 2 - Vertical Slice (12-16 Weeks)

## Goals

- Ship one fully playable region with end-to-end progression loop.

## Scope

- 1 region (`Sotanos de la Hacienda`)
- 8 classes
- Full Hacienda baseline buildings
- 1 apex boss + 1 mini-boss
- 30-40 event/curio variants

## Deliverables

- UI for prep, mission select, map traversal, combat, extraction.
- First-pass art direction implemented in production assets.
- Audio mood package and narrator prototype.
- Internal telemetry pipeline for:
  - mission success rates
  - stress spikes
  - economy health

## Exit Criteria

- New players complete 3-loop cycle without manual guidance.
- Mission success target 55-70% on standard risk.
- No blocking progression exploits or deadlocks.

## 3) Phase 3 - Alpha Expansion (16-24 Weeks)

## Goals

- Expand into content-complete alpha for core campaign.

## Scope

- 4-5 regions
- 16 classes
- Complete enemy family matrix
- Regional boss ladder and portal preconditions
- 120+ curios/events

## Deliverables

- Full meta progression and building upgrade trees.
- Difficulty tiers apprentice/veteran/champion.
- Narrative chapter structure through portal reveal.
- Balance pass #1 (economy, stress, attrition, class viability).

## Exit Criteria

- All core systems feature-complete.
- Campaign playable start-to-final-arc with placeholder polish acceptable.
- Crash-free rate above 98% in internal sessions.

## 4) Phase 4 - Beta and Polish (12-18 Weeks)

## Goals

- Improve clarity, stability, onboarding, and final tuning.

## Deliverables

- UX onboarding pass:
  - tooltips
  - glossary
  - guided first-week tutorial
- Performance optimization and memory budget compliance.
- Localization-ready text pipeline.
- Final balancing:
  - class parity
  - boss difficulty ramps
  - economy sink/faucet equilibrium
- QA regression suite and save migration tests.

## Exit Criteria

- Telemetry targets hit:
  - acceptable churn after week 1
  - stable economy slope
  - class diversity in successful comps
- Certification checklist complete (if platform release).

## 5) Phase 5 - Launch and Live Ops (Ongoing)

## Launch Window Goals

- Stable day-1 patch.
- Hotfix process under 72 hours for critical issues.
- Community channels and feedback triage board live.

## Post-Launch Cadence (Suggested)

- Every 4-6 weeks:
  - event modifier
  - trinket set
  - balance micro-patch
- Every 10-14 weeks:
  - new class or mini-region pack
  - challenge mode or boss variant

## 6) Production Risk Register

- Tone risk:
  - Satire may read as insensitive.
  - Mitigation: cultural review pass and writing standards.
- Scope risk:
  - Content-heavy design can overrun.
  - Mitigation: lock vertical slice and strict cutline policy.
- Balance risk:
  - Attrition and stress may feel unfair.
  - Mitigation: telemetry-driven weekly tuning.
- Technical risk:
  - Save corruption in long campaigns.
  - Mitigation: robust versioned save schema and automated tests.

## 7) KPI Targets by Milestone

- Vertical slice:
  - D1 prototype retention target: >= 45%
- Alpha:
  - Average mission completion target: >= 60%
  - Team wipe frustration threshold: <= 25% sessions
- Beta:
  - Onboarding comprehension score: >= 80%
  - Economy bankruptcy rate: <= 15% campaigns

## 8) Immediate Next Actions (Execution Backlog)

1. Turn combat formulas into machine-readable balancing data.
2. Build encounter and map generator prototype.
3. Implement 4 starter classes and 20 enemy units.
4. Run first balance playtest wave and tune stress economy.
5. Lock vertical slice content cut and production sprint plan.
