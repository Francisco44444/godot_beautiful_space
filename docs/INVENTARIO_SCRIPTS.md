# Inventario completo de scripts — 8 de noviembre de 2026

Mundo completo arrancado desde `startup.tscn`, Puerto Alba, Villa Robledal y Bosque Umbrío. Complementa la [auditoría y sus límites](AUDITORIA_SCRIPTS.md).

Los recuentos corresponden a nodos adjuntos y callbacks habilitados; no implican que cada nodo haga trabajo pesado. Los modificadores de esqueleto pueden usar callbacks internos del motor. Los tiempos son la suma propia de GDScript por archivo, expresada como el **máximo de las tres zonas** antes y después, con el coste añadido del perfilador. No son tiempos de GPU ni medidas de FPS.

Los guiones indican que no se registró tiempo propio; no demuestran ausencia de coste en otras situaciones. El autoguardado está detenido durante el perfil y se mide por separado.

| Archivo | Nodos | Proceso | Física | Máx. antes (ms/f) | Máx. después (ms/f) |
| --- | ---: | ---: | ---: | ---: | ---: |
| [adventure_arrow.gd](../scripts/adventure_arrow.gd) | 0 | 0 | 0 | — | — |
| [adventure_pickup.gd](../scripts/adventure_pickup.gd) | 0 | 0 | 0 | — | — |
| [adventure_resource.gd](../scripts/adventure_resource.gd) | 216 | 0 | 0 | — | — |
| [adventure_system.gd](../scripts/adventure_system.gd) | 1 | 0 | 0 | — | — |
| [ambient_audio.gd](../scripts/ambient_audio.gd) | 1 | 1 | 0 | 0.0172 | 0.0163 |
| [animated_clouds.gd](../scripts/animated_clouds.gd) | 1 | 1 | 0 | 0.0072 | 0.0070 |
| [archer_arms_modifier.gd](../scripts/archer_arms_modifier.gd) | 1 | 0 | 0 | 0.0283 | 0.0302 |
| [breakable_prop.gd](../scripts/breakable_prop.gd) | 5 | 0 | 0 | — | — |
| [building_assembler.gd](../scripts/building_assembler.gd) | 0 | 0 | 0 | — | — |
| [building_catalog.gd](../scripts/building_catalog.gd) | 0 | 0 | 0 | — | — |
| [building_recipes.gd](../scripts/building_recipes.gd) | 0 | 0 | 0 | — | — |
| [building_solver.gd](../scripts/building_solver.gd) | 0 | 0 | 0 | — | — |
| [cave_memory.gd](../scripts/cave_memory.gd) | 22 | 0 | 0 | — | — |
| [charge_storm.gd](../scripts/charge_storm.gd) | 0 | 0 | 0 | — | — |
| [combate_cooperativo.gd](../scripts/combate_cooperativo.gd) | 1 | 0 | 0 | — | — |
| [desert_breeze.gd](../scripts/desert_breeze.gd) | 1 | 1 | 0 | 0.0146 | 0.0148 |
| [dust_devil.gd](../scripts/dust_devil.gd) | 1 | 1 | 0 | 0.0015 | 0.0017 |
| [estado_fragmentado.gd](../scripts/estado_fragmentado.gd) | 0 | 0 | 0 | — | — |
| [exploration_manager.gd](../scripts/exploration_manager.gd) | 1 | 0 | 1 | 0.0218 | 0.0202 |
| [forest_wonders.gd](../scripts/forest_wonders.gd) | 1 | 1 | 0 | 0.0028 | 0.0026 |
| [game_settings.gd](../scripts/game_settings.gd) | 1 | 0 | 0 | — | — |
| [hollow_cave.gd](../scripts/hollow_cave.gd) | 4 | 4 | 0 | 0.0010 | 0.0010 |
| [horse.gd](../scripts/horse.gd) | 1 | 0 | 1 | 0.0179 | 0.0171 |
| [house_interior.gd](../scripts/house_interior.gd) | 0 | 0 | 0 | — | — |
| [hud.gd](../scripts/hud.gd) | 1 | 1 | 0 | 0.0205 | 0.0210 |
| [inventory_manager.gd](../scripts/inventory_manager.gd) | 1 | 0 | 0 | — | — |
| [island_environment.gd](../scripts/island_environment.gd) | 1 | 1 | 0 | 0.0242 | 0.0240 |
| [island_map.gd](../scripts/island_map.gd) | 2 | 2 | 0 | 0.1685 | 0.1776 |
| [kill_cam.gd](../scripts/kill_cam.gd) | 1 | 0 | 0 | — | — |
| [library_animation.gd](../scripts/library_animation.gd) | 1 | 0 | 0 | 0.0208 | 0.0231 |
| [lobby_directory.gd](../scripts/lobby_directory.gd) | 1 | 1 | 0 | 0.0006 | 0.0005 |
| [medieval_set_dressing.gd](../scripts/medieval_set_dressing.gd) | 1 | 0 | 0 | — | — |
| [medieval_villager_visual.gd](../scripts/medieval_villager_visual.gd) | 0 | 0 | 0 | — | — |
| [network_motion.gd](../scripts/network_motion.gd) | 0 | 0 | 0 | — | — |
| [network_session.gd](../scripts/network_session.gd) | 1 | 0 | 1 | 0.0142 | 0.0138 |
| [pause_menu.gd](../scripts/pause_menu.gd) | 1 | 0 | 0 | — | — |
| [player.gd](../scripts/player.gd) | 1 | 1 | 1 | 0.3121 | 0.3146 |
| [quaternius_obj_loader.gd](../scripts/quaternius_obj_loader.gd) | 0 | 0 | 0 | — | — |
| [quaternius_wildlife.gd](../scripts/quaternius_wildlife.gd) | 1 | 0 | 1 | 0.1068 | 0.1050 |
| [render_bosque.gd](../scripts/render_bosque.gd) | 1 | 1 | 0 | 0.0025 | 0.0023 |
| [rpg_anvil.gd](../scripts/rpg_anvil.gd) | 6 | 0 | 0 | — | — |
| [rpg_arena_hazard.gd](../scripts/rpg_arena_hazard.gd) | 5 | 0 | 5 | 0.0074 | 0.0073 |
| [rpg_bestiary.gd](../scripts/rpg_bestiary.gd) | 0 | 0 | 0 | — | — |
| [rpg_boss.gd](../scripts/rpg_boss.gd) | 5 | 0 | 5 | 0.0050 | 0.0046 |
| [rpg_boss_arena.gd](../scripts/rpg_boss_arena.gd) | 5 | 0 | 0 | — | — |
| [rpg_campaign.gd](../scripts/rpg_campaign.gd) | 1 | 0 | 0 | — | — |
| [rpg_cave_gate.gd](../scripts/rpg_cave_gate.gd) | 4 | 0 | 0 | — | — |
| [rpg_cinematic.gd](../scripts/rpg_cinematic.gd) | 1 | 0 | 0 | — | — |
| [rpg_companion.gd](../scripts/rpg_companion.gd) | 0 | 0 | 0 | — | — |
| [rpg_dialogue.gd](../scripts/rpg_dialogue.gd) | 0 | 0 | 0 | — | — |
| [rpg_enemy.gd](../scripts/rpg_enemy.gd) | 260 | 0 | 260 | 0.4281 | 0.4258 |
| [rpg_forge.gd](../scripts/rpg_forge.gd) | 0 | 0 | 0 | — | — |
| [rpg_npc.gd](../scripts/rpg_npc.gd) | 24 | 0 | 0 | — | — |
| [rpg_prologue.gd](../scripts/rpg_prologue.gd) | 1 | 0 | 0 | — | — |
| [rpg_sidequests.gd](../scripts/rpg_sidequests.gd) | 1 | 0 | 0 | — | — |
| [rpg_story_catalog.gd](../scripts/rpg_story_catalog.gd) | 0 | 0 | 0 | — | — |
| [rpg_story_runtime.gd](../scripts/rpg_story_runtime.gd) | 1 | 1 | 0 | 0.0982 | 0.0985 |
| [save_game_manager.gd](../scripts/save_game_manager.gd) | 1 | 0 | 0 | — | — |
| [startup_loader.gd](../scripts/startup_loader.gd) | 0 | 0 | 0 | — | — |
| [third_person_camera.gd](../scripts/third_person_camera.gd) | 1 | 0 | 1 | 0.0083 | 0.0076 |
| [ui_theme.gd](../scripts/ui_theme.gd) | 0 | 0 | 0 | — | — |
| [ui_vital_bar.gd](../scripts/ui_vital_bar.gd) | 3 | 3 | 0 | 0.0008 | 0.0006 |
| [vegetation_layout_cache.gd](../scripts/vegetation_layout_cache.gd) | 0 | 0 | 0 | — | — |
| [vegetation_scatter.gd](../scripts/vegetation_scatter.gd) | 1 | 1 | 0 | 0.7560 | 0.0156 |
| [village_folk.gd](../scripts/village_folk.gd) | 1 | 0 | 1 | 1.1199 | 1.0710 |
| [village_layout.gd](../scripts/village_layout.gd) | 0 | 0 | 0 | — | — |
| [village_neighbour.gd](../scripts/village_neighbour.gd) | 87 | 0 | 0 | 0.0473 | 0.0481 |
| [village_rider_pose.gd](../scripts/village_rider_pose.gd) | 1 | 0 | 0 | 0.0057 | 0.0061 |
| [village_street.gd](../scripts/village_street.gd) | 0 | 0 | 0 | — | — |
| [village_work_pose.gd](../scripts/village_work_pose.gd) | 4 | 0 | 0 | 0.0310 | 0.0317 |
| [weapon_arm_modifier.gd](../scripts/weapon_arm_modifier.gd) | 1 | 0 | 0 | 0.0004 | 0.0003 |
| [weapon_charge_effect.gd](../scripts/weapon_charge_effect.gd) | 0 | 0 | 0 | — | — |
| [world.gd](../scripts/world.gd) | 1 | 1 | 1 | 0.1265 | 0.1269 |
