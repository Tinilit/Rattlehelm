# Stage A animation catalog

The guide pages on the documentation site returned an access error in the build environment. The sections below were read in the corresponding source documents of the official `godot-docs` **4.7** branch. Runtime checks used Godot **4.7.2 Standard**.

## Godot references and decisions

- **Cutout rigs.** Use local joint origins, compose rigid sprite layers as children of bones and mirror the complete rig around the floor point. Each bone has an explicit local rest. The weapon grip is a marker under the near wrist. [Cutout animation](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/animation/cutout_animation.rst) · [2D skeletons](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/animation/2d_skeletons.rst) · [Bone2D](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/classes/class_bone2d.rst)
- **Locomotion and blending.** Keep the canonical pose in a one-key RESET clip. A four-tick AnimationTree crossfade connects idle and stride. Place the physical root in the physics tick and reset interpolation on placement or a discrete mirror change. [Introduction to animation](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/animation/introduction.rst) · [AnimationTree](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/animation/animation_tree.rst) · [Using physics interpolation](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/physics/interpolation/using_physics_interpolation.rst)
- **Action timing.** Author skeletal position and rotation with value tracks. The AnimationTree owns playback and advances one simulation step per resolved tick. Actions start explicitly, including after an interrupt. Contact and audio cues come from the action definition and the simulation. Hitstop leaves the last evaluated pose in place. [Animation track types](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/animation/animation_track_types.rst) · [AnimationTree API](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/classes/class_animationtree.rst) · [AnimationMixer API](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/classes/class_animationmixer.rst)
- **Room props.** The portcullis easing and practice target damping are procedural property motion, using the same ownership principle as a property track. The room allows the interaction only when the portcullis has finished rising. [2D sprite animation](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/2d/2d_sprite_animation.rst) · [Animation track types](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/animation/animation_track_types.rst)
- **Effects.** Trail samples come from the tip marker and expire after their owner stops writing samples. Finite spark objects originate at the resolved contact with a local lifetime. Camera shake is an offset on the room camera. The HUD has a separate CanvasLayer. [2D particle systems](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/2d/particle_systems_2d.rst) · [Tween](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/classes/class_tween.rst) · [Camera2D](https://raw.githubusercontent.com/godotengine/godot-docs/4.7/classes/class_camera2d.rst)

## Character layers

The base watchman has bare feet, exposed skin, trousers and a rusted sword. Each fighter has an original painted atlas. Each body part uses a separate `AtlasTexture` region, with its painted joint centered on the corresponding bone. The sword and club use separate regions from the same atlases.

The far arm and thigh draw behind the torso and hip. On the watchman, the shins tuck behind the thighs at the knees, the bare feet sit behind the trouser cuffs and the sash covers the lower edge of the torso. The head draws over the shoulder during the windup. The free arm uses a shorter far-side silhouette and its own fist sprite. The idle keys keep that hand below the sword and the stride swings it against the opposite leg. The gripping hand draws over the sword handle. These layers use scene tree order so the entire fighter sorts with the other actors at floor depth. The Gatekeeper wears a helmet scene mounted on its head bone.

To add gear, use a scene rooted in Node2D with the joint at its origin. Attach it with `FighterRig.equip_wearable()` or instance it under a named gear anchor in either rig. Use `HeadGear`, `TorsoGear` and `BackGear` for core items and the matching `Near` and `Far` limb anchors for armor. `OffHandGear` is available for a shield or offhand item. The held weapon uses its own socket. A sword scene marks its damaging edge with `BladeRoot` and `Tip`.

## Clips and acceptance checks

These clips share the same skeleton layout in `WardenRig.tscn` and `GatekeeperRig.tscn`. The run tests resolve clip tracks against both rigs, check the arm hierarchy and sample hand clearance in both facing directions. They also check that the watchman's painted leg joints overlap through a full stride. The browser playthrough exercises the common room and combat path.

| ID | Family and reference | Authored motion | Acceptance check |
| --- | --- | --- | --- |
| `RESET` | Cutout rigs, locomotion | One key for every animated property | Reload either rig and compare its neutral stance |
| `idle` | Locomotion and blending | Small chest and arm motion with a planted stance | Ten seconds of idle leave floor position and attack state intact |
| `stride` | Locomotion and blending | Separate reach, heel contact, push-off and swing poses | Start and stop in both directions and watch the support foot |
| `takeoff` | Locomotion and blending, action timing | Three ticks of knee compression and extension | The feet stay on the floor during anticipation |
| `airborne` | Locomotion and blending | Tucked rise, open apex and falling stance | The silhouette rises about 90 px while the shadow stays on the floor |
| `land` | Locomotion and blending | Absorb and recover over seven ticks | Landing reaches the same floor plane and emits dust at the feet |
| `roll` | Action timing | Head tucks into the turn and hip height follows the part of the pose touching the floor | Observe a full turn on both sides and test the 24-tick movement against a wall |
| `stagger` | Action timing | Pelvis checks its motion and the head lags away from the hit | A confirmed hit places the reaction in the same simulation tick |
| `fall` | Action timing | Lean back, buckle and settle low | A fatal hit leaves an inactive fighter on the floor |
| `flask` | Action timing | Far hand lifts the bottle toward the face | Interrupt before tick 16 or let the cue spend exactly one charge and restore health |
| `kick` | Action timing | Far leg supports weight as the near foot pushes forward | Use a neutral tap at close range and see the target move away |
| `air_slash` | Action timing | Tucked launch with a descending blade | Make one deliberate attack per jump and verify its height band |
| `slash_1` | Action timing | Near foot anchors a high diagonal cut and the torso follows through | The sampled blade edge hits across a gap on tick 5 and misses a target in a different lane |
| `slash_2` | Action timing | Reset from the first cut into a rising reverse arc | A buffered tap reaches the second clip and opens a new hit list at tick 6 |
| `slash_3` | Action timing | Wider weight shift and a longer low finish | Tick 10 opens the sweep and the follow-through remains readable in both directions |
| `club_sweep` | Action timing | Shoulder lifts into a committed swing and sinks into recovery | The lane preview warns before tick 29 and a sidestep produces a clean miss |
| Portcullis | Room props | Thirty-five-tick lift behind the arch | The interaction comes online after the final lift tick |
| Straw and shield | Room props | Damped turn starts on a confirmed contact | Observe larger straw deflection and distinct audio on metal |
| Tip trail | Effects | Nine recent world-space samples follow the blade | The trail begins on the swing cue and decays after the active window |
| Contact sparks and camera | Effects | Expanding ring and short, optional shake | Cue placement follows the contact and volume, shake and particle controls work independently |
| Landing dust | Effects | Two short puffs separate along the floor | Dust starts at the landing point and respects the particle setting |
