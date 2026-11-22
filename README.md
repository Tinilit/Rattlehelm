# Rattlehelm

Rattlehelm is a single-player fantasy brawler. The Stage A playtest takes the watchman from the training yard to a fight with the Gatekeeper. Hit the straw dummy and the hanging shield, then cross the yard and press **E** at the gate. When the club winds up, step up or down out of its marked lane. Roll to the other side, line up the shadows and strike during recovery.

## Run the game

Open `project.godot` in **Godot 4.7.2 Standard** and press **F5** to start the game at its title screen. The same entry point is available from the repository root.

```sh
godot --headless --path . --import
godot --path .
```

| Action | Keyboard | Xbox layout |
| --- | --- | --- |
| Move | WASD or arrow keys | Left stick or D-pad |
| Sword, combo, kick and airborne slash | J | X |
| Jump | Space | A |
| Roll | K or left Shift | B |
| Pass through the gate | E | Y |
| Drink one 30 HP flask | U | LB |
| Pause | Esc | Menu |
| Confirm and back | Enter or Space, Esc | A, B |
| Simulation diagnostics | F4 | — |

Tap **J** for each link of the combo. A neutral tap at very close range kicks. Hold a direction as you press **K** to aim the roll. Training returns to the title through its open gate. The playtest route continues into the encounter and ends when you go through the cleared gate.

## Reproduce a combat report

Pause to get the build name. Use **F4** to show the combat tick, current action and floor coordinates. Record the room, position, direction and inputs around the event. The Stage A route and encounter are fixed, so the same build and fixed-tick input sequence reproduce the same combat state without a route seed. Profile preferences live in Godot's `user://play_preferences.cfg`.

```sh
godot --headless --path . --quit-after 120
for fps in 30 60 120; do
  godot --headless --path . --fixed-fps "$fps" --script res://tests/run_tests.gd
done
```

## Author and check content

- Create an attack `.tres` with a unique ID, fixed-tick phases, contact settings and an animation state. Assign it to a `WeaponDef` and point the weapon at a held scene with `Grip` and `Tip` markers. Blade-driven strikes also need a `BladeRoot` marker. Their reach follows the animated edge during active ticks. The sword resources show the complete path from the pack to the hand socket and attack executor. See [the animation catalog](actors/rig/ANIMATION.md).
- Create an `EnemyDef` that references a fighter scene and a registered weapon. Add the enemy to an `EncounterDef` roster and provide one spawn marker per roster entry. The current enemy policy approaches, lines up and uses the authored opener.
- Add the `RoomDef`, enemy and weapon definitions to [the Fortress pack](content/packs/fortress.tres). Add the room ID to the playtest route in [RunDirector](game/run_director.gd) when it should appear in a run. Run the headless check, then play into the room from the main menu and verify the exit condition. The catalog reports invalid definitions with their resource path and field.

## Export and test

Install the official **4.7.2.stable** export templates through the Godot editor. The build commands use the presets in the repository.

```sh
mkdir -p build/web
godot --headless --path . --export-release "Web Playtest" build/web/index.html
```

Serve the web export over HTTP or HTTPS. Keep the files and relative paths created by Godot together. For a local Chromium check at the project URL prefix, serve `build/web` as `/Rattlehelm/`, then run the smoke test.

```sh
npm ci --prefix ci
ci/node_modules/.bin/playwright install chromium
node ci/browser_smoke.mjs http://127.0.0.1:8765/Rattlehelm/ local
```

[The playtest workflow](.github/workflows/playtest.yml) runs the import, headless checks and Chromium smoke test on pull requests, pushes to `main` and manual dispatches. The build stamp in Pause comes from the workflow commit. Enable the live site in **Settings → Pages → Source → GitHub Actions**. The job serializes deployments, checks the tip of `main` and exercises the returned HTTPS URL. A live URL and workflow run become available after the first confirmed deployment.

## Playtest status

Stage A covers the practice targets, the single Gatekeeper encounter and the sword. Stage B adds the mace, the short fortress route, more techniques and the Gate Bellringer. Branching runs, checkpoints, the full campaign, input remapping and Ukrainian localization are later work. The interface currently uses English locale keys.

The authored motion, art and audio were created for Rattlehelm. Font notices are in [the font directory](ui/fonts).

The clean-source import and normal title launch passed. The headless suite passed 60 checks at each of 30, 60 and 120 render FPS. In Chromium at 720p and 1080p, scripted browser input exercised the two practice materials, dodged the club in each direction, rolled across the Gatekeeper, counterattacked and went through the cleared gate. The 1080p run used the in-game settings to disable shake, particles and health numbers.

The release workflow publishes the browser version. Physical controller validation remains pending.

On Linux x64, Chromium 156 used software WebGL 2 through SwiftShader. With two actors in the Watch Gate, browser frame intervals had a 33.3 ms median and 66.7 ms maximum at 1280×720 across 284 samples. At 1920×1080 with the three effects options disabled, the median was 66.6 ms and the maximum was 100.1 ms across 192 samples. These are browser frame intervals during the automated playthrough.
