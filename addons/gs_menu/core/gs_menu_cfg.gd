class_name GSMenuCfg
extends RefCounted

## Reads `admin_menu.yml` from `cfg/addons/gs_menu/`, the operator's `cfg/server/addons/gs_menu/` over it.
## A flat `legacy_dir/admin_menu.yml` is still read (one WARN) while no new copy exists, until [constant GSCfgLegacy.REMOVE_AFTER].

const CFG_ADDON := "gs-menu"
const ADMIN_MENU_FILE := "admin_menu.yml"


## Value: the merged tree. Maps merge key by key, a list or scalar is replaced whole.
static func load_admin_menu(legacy_dir: String = "res://cfg") -> GSResult:
	var tree := {}
	var res := GSAddonConfig.apply_file(
		CFG_ADDON, ADMIN_MENU_FILE, legacy_dir,
		func(values: Dictionary, path: String) -> PackedStringArray:
			GSAddonConfig.merge(tree, values)
			return PackedStringArray([path])
	)
	if not res.ok:
		return res
	return GSResult.success(tree)
