# API levels

What each `GSMenuApi.LEVEL` added; the rule for bumping is on `GSAddonApi`.

1: the first release: GSMenu, GSMenuScreen, GSMenuHelp, GSMenuPicker, GSMenuLayoutEditor, GSMenuScoreboard, GSMenuSettings, GSMenuApplier, GSMenuStock, GSMenuBindings, GSMenuConfig, GSMenuPage, GSMenuSection, GSMenuRow, GSMenuKit, GSMenuPalette, GSMenuThemes.

2: GSMenuNetStat (follow, read_settings) and GSMenu.net_stat; GSMenuStock advanced_page(), declare_net_stat() and the net_stat, net_stat_height and net_stat_position settings; GSMenuConfig.net_stat.

3: voice: GSMenuStock.GROUP_VOICE (in DEFAULT_GROUPS), VOICE_ROWS, input_device_row(), the voice_mode and voice_input_device settings; GSMenuBindings.add_voice() (bind_voice_talk on the gs_voice_talk action); GSMenuApplier.bind_voice(), VOICE_SERVICE and voice_available_changed; GSMenuSettings.bind_voice(); GSMenu.hide_rows().

4: the help key and the stock Leave: GSMenuBindings.HELP_ACTION/HELP_SETTING/HELP_KEY, add_help(), help_group(), defaults_on(); GSMenu.help_action defaults to HELP_ACTION, leave_on_its_own, leave_link, leave_service, leave(), leave_label(); GSMenuHelp.about, add_text(), heading(), help_key_shown(); GSMenuSettings.leave_on_its_own and _fill_help(); GSMenuConfig.help_hint and GSMenu.help_hint, the HUD's help plate.

5: the map menu: GSMenuMaps; GSMenu.use_maps(), open_maps(), maps, maps_action, toast(), toast_text(), open_picker(items, title, close_action, on_chosen); GSMenuBindings MAPS_ACTION/MAPS_SETTING/MAPS_KEY and add_maps(); GSMenuSettings.map_menu and use_maps(); picker rows' `detail` and `thumbnail`, GSMenuPicker.thumbnail_texture().

6: the loadout menu: GSMenuLoadout, GSMenuLoadoutScreen; GSMenu.use_loadout(), open_loadout(), open_loadout_screen(), loadout, loadout_screen, loadout_action; GSMenuBindings LOADOUT_ACTION/LOADOUT_SETTING/LOADOUT_KEY and add_loadout(); GSMenuSettings.loadout_menu and use_loadout().

7: the HUD follows the theme: GSMenu.follow_hud(), unfollow_hud(), followed_huds(), hud_scale(); GSMenuPalette.hud_theme(), NUMBERS and the hud_edge, hud_ink, hud_highlight, hud_keycap, hud_keycap_text, hud_keycap_edge and hud_team_fill fields; the hud_scale stock setting and its row; the Arcade stock theme. Needs GameSpice UI 6.

8: moved defaults: GSMenuBindings.renamed(), renamed_defaults and settle(); apply_all() and GSMenuApplier.apply_all() settle two rows stored on one key. Needs the GameSpice Settings that has GSSettingsDef.previous_defaults.

9: GSMenuFrameClock (wall-clock frame times by part); GSMenuNetStat.frames, net_source, net_manager() and the level-3 frame, renderer and prediction rows.

10: extra keys on one action: GSMenuBindings.add_extra(), is_extra(), is_none(), NONE, remove_setting(); the wheel: add_wheel_jump(), remove_wheel_jump(), add_wheel_weapons() and the WEAPON_*/WHEEL_JUMP_* constants; GSMenuKeyButton.clearable (Delete clears).

11: GSProfileEditorScreen (list profile kinds and ids, edit one in GSUiForm; save and reset are callables).

12: GSMenuCfg.load_admin_menu reads cfg/addons/gs_menu/admin_menu.yml and the operator's cfg/server/addons/gs_menu/, with the flat cfg/admin_menu.yml as a shim until 2026-12-31. Needs GameSpice Core API level 17.

13: GSAddonConfigEditorScreen (edit the player's user-tier override of addon cfg files in GSUiForm; needs GameSpice Core API 18).

14: GSAddonConfigEditorScreen undo()/is_open()/close(); GSMenu.use_mods adds a Mods action to Escape.

15: GSMenuStock.add_gore_row (the Blood splatters row, for a game that declares `gore`).

16: GSMenuBindings.add_avatar_actions() and the AVATAR_* constants (emote, pose, gesture on , . /); GSMenuSettings.avatar_actions adds them.

17 GSMenuTeams, GSMenuTeamScreen, GSMenu.use_teams/open_teams/show_teams and GSMenuBindings.add_teams (the team menu on the period key; the avatar Pose default moves to Semicolon).

18 GSMenuStock.performance_section and PROFILER_SERVICE: the Advanced page draws a Performance card from a placed `gs_profiler` service's `make_menu_panel(kit)`, duck-typed.
19 GSMenuTeams.default_when_unwired and default_offer(): the period key opens a free-for-all Play/Spectate menu when no server link and no offer is wired, instead of a toast.
20 GSMenuBindings.add_workbench, WORKBENCH_ACTION/SETTING/KEY (the workbench toggle on the semicolon, added by GSMenuSettings where GameSpice Workbench is linked; the avatar Pose default moves to the apostrophe).

21 The Maps / Game modes tabs: GSMenuMaps.modes_fn/mode_group/modes_tab/apply_mode_now/mode/toggle_tab()/has_tabs(); GSMenu.modes_action; GSMenuBindings.add_modes and MODES_*; GSMenuSettings.map_modes; GSMenuPicker.tabs/tab/pick_closes/tab_clicked.
22 GSMenuGameSpec and GSMenuGameSettings: a game declares its settings menu (names, field of view, ambient and Comfort rows, left-out stock keys, key table, help text) as data.
23 The Gamespice stock theme; GSMenuPalette.glow and flame(); GSMenuKit.focus_ring() and flame_strip(); GSMenuThemes.platform_default() and PLATFORM_SETTING (the project setting gs_menu/theme/platform_default, which GSMenuConfig.make_themes puts first).
