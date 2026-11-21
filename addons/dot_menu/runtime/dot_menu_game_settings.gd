class_name GSMenuGameSettings
extends GSMenuSettings

## [GSMenuSettings] declared by data: a game passes a [GSMenuGameSpec] and has its settings, key table, help screen and
## Comfort row, with no settings class of its own to keep. Behaviour is the base class's.

var spec: GSMenuGameSpec = null


func _init(game_spec: GSMenuGameSpec = null) -> void:
	if game_spec == null:
		return
	spec = game_spec
	name = "Settings"
	directory = spec.settings_dir
	app_namespace = spec.app_namespace
	schema = spec.make_schema()
	config = GSMenuConfig.new()
	config.brand_name = spec.brand_name
	if not spec.config_settings.is_empty():
		config.settings = spec.config_settings.duplicate(true)
	manage_pointer = spec.manage_pointer
	migrations = spec.migrations.duplicate()
	if spec.bindings_maker.is_valid():
		bindings = spec.bindings_maker.call()
	config.open_on_pointer_release = spec.open_on_pointer_release
	if spec.help_hint != &"":
		config.help_hint = spec.help_hint
	# By name: an older GameSpice Menu has no such property.
	if spec.menu_button_corner != &"" and &"menu_button_corner" in config:
		config.set(&"menu_button_corner", spec.menu_button_corner)
	var _layered := config.load_layered()


func setup(store: GSSettingsStore = null, with_menu: bool = true) -> GSResult:
	var where := store
	if spec != null and spec.before_setup.is_valid():
		where = spec.before_setup.call(self, store)
	var made := super.setup(where, with_menu)
	if applier != null and spec != null and spec.fov_transform.is_valid():
		applier.fov_transform = spec.fov_transform
	if menu != null and spec != null and spec.gore_text != "":
		GSMenuStock.add_gore_row(menu.page(&"video"))
	if menu != null and spec != null and spec.comfort_row_text != "":
		var general := menu.page(&"general")
		if general != null:
			general.section("Comfort").add(GSMenuRow.toggle(&"reduce_motion", "Reduce motion", spec.comfort_row_text))
	if menu != null and spec != null:
		for entry: Array in spec.extra_rows:
			var page := menu.page(entry[0])
			if page != null:
				page.section(entry[1]).add(entry[2])
		for entry: Array in spec.page_makers:
			var _p := menu.add_page(entry[0].call(), entry[1])
	return made


func _fill_help(help: GSMenuHelp) -> void:
	if spec != null:
		spec.fill_help(help)
