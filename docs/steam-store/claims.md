# Store claims gate

page_ready: false

Every marketed claim maps to a row of docs/inventory.csv (matched by a phrase of its "System / feature" column). tools/store_text_check.py fails if a row is `missing` and warns if it is `rough`/`partial`; while any marketed row is rough, `page_ready` must stay false. Flip it to true only when every row below is done (the Steamworks "submit for review" step in docs/STEAM.md is gated on it).

| id | claim | inventory row phrase | tests |
|----|-------|----------------------|-------|
| c1 | Two full stories | Penguin arc: 5 chapters | story tests, playtest |
| c2 | Two full stories (gangster) | Gangster arc: 5 chapters | story tests, playtest |
| c3 | Crops across four seasons | Farming: 134 crops | farm tests |
| c4 | Raise and rehome animals | Ranching core | ranch tests |
| c5 | Villagers to befriend | villagers: schedules | hearts tests |
| c6 | Date and marry | Dating/marriage | romance tests |
| c7 | Big regions to explore | Mega regions | mega tests |
| c8 | Battle campaigns | Battles, campaigns | battle tests |
| c9 | Arcade and bowling | Rec Center | rec tests |
| c10 | Community farm | Community farm (Commons) | commons tests |
| c11 | Online co-op (GATED: use short ALT B until done) | Co-op up to 8 | coop_test, net_e2e (live relay) |
| c12 | Full controller support | Controllers: pad bindings | pad tests, Deck checklist |
| c13 | Accessibility options | Accessibility and Options | options tests |
| c14 | Decorate house and yard | Decor catalogue | decor tests |

Steam category checkboxes (Online Co-op, Cross-Platform Multiplayer: web/phone and Steam meet on the relay) follow the same gate: tick them only when c11 is done.
