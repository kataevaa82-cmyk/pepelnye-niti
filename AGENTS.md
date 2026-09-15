# Working agreement

This is the Godot project «Пепельные нити» (`pepelnye-niti`), not a web framework app.
Keep GDScript, Godot 4.4.1, Compatibility, single-threaded HTML5 and Russian UI.
Do not replace the project with Three.js, React, a Sites app or a JS-only mockup.
Do not mix it with Room 1604, White Noon or the user's other repositories.

## Product boundaries

- Original stitched-creature / abandoned-machine atmosphere and route-making destruction.
- One mission: clear paths before collecting the first of three cores, then escape.
- Fixed structural frame; small destructible block grids; a 48-body debris cap.
- Baseline target is desktop browsers. Touch controls require real-device QA before declaring mobile support.
- Do not include extracted movie/game assets, trademarks as game branding, paid dependencies or secrets.

## Verification

- Run `node --test tests/bridge.test.cjs` and `python tools/validate_source.py`.
- Use Godot 4.4.1 with matching templates; the authoritative engine checks are in
  `python tools/export_web.py --godot /path/to/godot` and `tests/smoke.gd`.
- Set `ASH_TESTING=1` when running `tests/smoke.gd` manually to avoid touching saves.
- The source validator is NOT a GDScript compiler. Do not call it an engine playtest.
- Render and manually play the exported build before publishing. Record actual measurements.
- On changing destruction, test unsupported collapse, restored removed cells, occluded core pickup,
  metal durability and the debris limit. On changing SDK code, test late initialization,
  focus loss, ad errors and no automatic resume.
- The platform integration uses `/sdk.js` when uploaded to Yandex. Never fake ad completion.
- Preserve save identity (`pepelnye-niti-v1` / `progress.json`) and add migrations on schema changes.

## Delivery

Keep source and Web-export archives distinct. A source ZIP is not a Yandex submission.
Do not claim the GitHub repo exists until its remote URL has been verified.
Do not publish the repo, deploy to Pages or submit to Yandex without authorization.
Current remote-repo status and unexecuted checks are documented in `docs/verification.md`.
