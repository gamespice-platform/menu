class_name GSMenuScoreboard
extends Control

## The scoreboard a player holds Tab for: the server, the teams, and a row per player (name, score, time, ping) plus the game's columns. Example: docs/examples.md.
## A snapshot in, a picture out: one dictionary (GameSpice Server's `scoreboard_snapshot` shape) feeds server, game and offline numbers through the same code. [member columns], [member decorate], [member group_by], [member sort_by] and the `build_*` callables customise it; `scoreboard_hidden` lets a player hide columns.
## Held, not opened: it never takes the mouse or keyboard, so it is not one of [GSMenu]'s overlays. [method feed_from] takes anything with `want_scoreboard(open)` and a `scoreboard_received` signal.

const CHANNEL := "menu.scoreboard"

## The stock setting holding the player's column choices. See [method parse_choices].
const SETTING := &"scoreboard_hidden"

signal opened()
signal closed()

## How a column's value is drawn.
const KIND_TEXT := &"text"
const KIND_NUMBER := &"number"
## Milliseconds, coloured by how bad they are; -1 is "-".
const KIND_PING := &"ping"
## Seconds, as 4:05 or 1:02:09.
const KIND_DURATION := &"duration"
## A Texture2D in the row; nothing when there is none.
const KIND_AVATAR := &"avatar"
## `build: func(kit, row) -> Control`.
const KIND_CUSTOM := &"custom"

## Inside a row, each side: room for the highlight's outline, which a number set flush
## right otherwise touches.
const ROW_PAD := 8

## The most of the view's height the panel takes; past it the rows scroll.
const MAX_HEIGHT_FRACTION := 0.8

var kit: GSMenuKit = null

var columns: Array[Dictionary] = default_columns()

## `func() -> Dictionary`: a snapshot to draw, asked for on open and every
## [member refresh_sec]. Wins over a feed when set — for offline play, or a game whose board
## is entirely its own numbers.
var source: Callable = Callable()

## `func(row: Dictionary) -> void`: edits each row before it is drawn.
var decorate: Callable = Callable()

## `func(snapshot: Dictionary) -> void`: edits the snapshot itself before it is drawn — teams
## and a header the client knows and the server did not send, rows for players that are not
## sessions. Given a copy, so the feed's own is never changed.
var prepare: Callable = Callable()

## The row field rows are grouped into teams by. Empty draws one list.
var group_by: StringName = &"team"

## The row field rows are ordered by, highest first, then by name.
var sort_by: StringName = &"score"

## `func(a: Dictionary, b: Dictionary) -> bool`, when one field is not enough.
var sort_with: Callable = Callable()

## Overrides, each given the kit: `func(kit, snapshot) -> Control`,
## `func(kit, team: Dictionary, rows: Array) -> Control`, `func(kit, row, columns) -> Control`. A team header's `rows` is reused by the next team: copy it to keep it.
var build_header: Callable = Callable()
var build_team_header: Callable = Callable()
var build_row: Callable = Callable()

## Used when the snapshot names no server: the game, offline.
var title_text: String = "Scoreboard"

## Two teams side by side, as the team shooters draw them, when there is room. Off stacks
## them.
var side_by_side: bool = true

## Seconds between redraws while it is held.
var refresh_sec: float = 0.5

## Refills the rows already drawn on a redraw instead of building every one again; off builds each row new (the older path).
## Only the stock rows are kept: a game's [member build_row] is always called.
var reuse_rows: bool = true

## The words under the rows for players on no team when there are teams.
var spectators_title: String = "Spectating"

var snapshot: Dictionary = {}

## What the player chose, by column key: true hides it, false shows it even when the game's column says `"hidden": true`.
## Keyed by column key, not position or title, so a game that reorders or retitles columns keeps every choice.
var player_hidden: Dictionary = {}

## Shown after a bot's name.
const BOT_TAG := "  BOT"
const SPECTATORS_GAP := ":  "
## A column with no format and no kind: [method format_value] then reads a value as str() does.
const _PLAIN := {}

var _feed: Object = null
var _frame: GSMenuScoreboardFrame = null
var _head: VBoxContainer = null
var _body: VBoxContainer = null
var _since := 0.0
var _built := false
var _drawn_sig := 0
var _live_rows: Array[PanelContainer] = []
var _row_pool: Array[PanelContainer] = []
var _pool_sig := 0
# Reused by every redraw, which runs on the refresh timer while the board is held: cleared, never allocated.
var _placed: Array[bool] = []
var _blocks: Array[Control] = []
var _members: Array = []
var _names := PackedStringArray()


## Avatar, name, score, time connected and ping. What every game starts from.
static func default_columns() -> Array[Dictionary]:
	return [
		{"key": &"avatar", "kind": KIND_AVATAR, "width": 0.0},
		{"key": &"name", "title": "Player", "width": 3.0},
		{"key": &"score", "title": "Score", "kind": KIND_NUMBER},
		{"key": &"seconds", "title": "Time", "kind": KIND_DURATION},
		{"key": &"ping", "title": "Ping", "kind": KIND_PING},
	]


func _ready() -> void:
	if kit == null:
		kit = GSMenuKit.new()
	GSMenuKit.fill_parent(self)
	# Held over a live game: it must never take a click or a key.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func restyle(new_kit: GSMenuKit) -> void:
	kit = new_kit
	if not _built:
		return
	_live_rows.clear()
	_row_pool.clear()
	GSMenuKit.clear(self)
	_build()
	if visible:
		redraw()


func _build() -> void:
	theme = kit.theme()
	_frame = GSMenuScoreboardFrame.new(kit)
	_head = _frame.head
	_body = _frame.body
	add_child(_frame)
	_built = true


## Sizes the window to the view now; the frame also does on every resize.
func _fit() -> void:
	if _frame != null:
		_frame.fit()


## Adds [param column] before the column keyed [param before], or at the end. A column with
## the same key is replaced in place.
func add_column(column: Dictionary, before: StringName = &"") -> void:
	for i in range(columns.size()):
		if columns[i].get("key") == column.get("key"):
			columns[i] = column
			return
	for i in range(columns.size()):
		if columns[i].get("key") == before:
			columns.insert(i, column)
			return
	columns.append(column)


func remove_column(key: StringName) -> bool:
	for i in range(columns.size()):
		if columns[i].get("key") == key:
			columns.remove_at(i)
			return true
	return false


## Whether the column keyed [param key] is hidden now: the player's choice if they made one,
## else the column's own `"hidden"`; never a required column. An unknown key is not hidden.
func column_hidden(column: Dictionary) -> bool:
	if column_required(column):
		return false
	var key := StringName(str(column.get("key", "")))
	if player_hidden.has(key):
		return bool(player_hidden[key])
	return bool(column.get("hidden", false))


## True for a column the player may not hide: `"required": true`, and by default the name
## (a board with no names tells nobody anything).
static func column_required(column: Dictionary) -> bool:
	return bool(column.get("required", str(column.get("key", "")) == "name"))


## The columns that are drawn, in order. Titles, rows and a game's `build_row` all use this,
## so any subset lays out the same way.
func visible_columns() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in columns:
		if not column_hidden(c):
			out.append(c)
	return out


## The columns a player is offered a switch for: titled and not required.
func optional_columns() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in columns:
		if not column_required(c) and str(c.get("title", "")) != "":
			out.append(c)
	return out


## Hides or shows the column keyed [param key] by the player's choice, redrawing an open board.
func set_column_hidden(key: StringName, hide: bool) -> void:
	player_hidden[key] = hide
	_changed_columns()


## The `scoreboard_hidden` setting's text: `ping,seconds` hides those; `+best` shows `best`
## though the game hides it. Tokens rather than a bare list so "the player chose to show it"
## survives, which a plain hidden set could not say.
static func parse_choices(text: String) -> Dictionary:
	var out := {}
	for token in text.split(",", false):
		var t := token.strip_edges()
		if t.begins_with("+"):
			if t.length() > 1:
				out[StringName(t.substr(1))] = false
		elif t != "":
			out[StringName(t)] = true
	return out


static func format_choices(choices: Dictionary) -> String:
	var parts := PackedStringArray()
	var keys := choices.keys()
	keys.sort()
	for k in keys:
		parts.append(str(k) if bool(choices[k]) else "+" + str(k))
	return ",".join(parts)


## Reads the `scoreboard_hidden` setting and redraws if it changed. A schema without it
## leaves every column to the game.
func read_settings(settings: GSSettingsManager) -> void:
	var text := ""
	if settings != null and settings.schema != null and settings.schema.has(SETTING):
		text = settings.get_string(SETTING, "")
	var parsed := parse_choices(text)
	if parsed == player_hidden:
		return
	player_hidden = parsed
	_changed_columns()


func _changed_columns() -> void:
	GSLog.debug(CHANNEL, "columns changed", {"hidden": ",".join(hidden_keys())})
	if visible:
		redraw()


func hidden_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for c in columns:
		if column_hidden(c):
			out.append(str(c.get("key", "")))
	return out


## Draws the server's roster: [param link] is told when the board opens and closes and its
## `scoreboard_received` is drawn. GameSpice Server's `GSClientLink`, or anything shaped like it.
func feed_from(link: Object) -> void:
	if _feed != null and _feed.has_signal(&"scoreboard_received") \
			and _feed.is_connected(&"scoreboard_received", show_snapshot):
		_feed.disconnect(&"scoreboard_received", show_snapshot)
	_feed = link
	if link != null and link.has_signal(&"scoreboard_received"):
		link.connect(&"scoreboard_received", show_snapshot)


## Draws [param snap] now, if held; otherwise keeps it for the next hold.
func show_snapshot(snap: Dictionary) -> void:
	if source.is_valid():
		return
	snapshot = snap
	if visible:
		redraw()


func open() -> void:
	if visible:
		return
	visible = true
	if _feed != null and _feed.has_method(&"want_scoreboard"):
		var _asked: Variant = _feed.call(&"want_scoreboard", true)
		var last: Variant = _feed.get(&"scoreboard")
		if last is Dictionary and not (last as Dictionary).is_empty() and not source.is_valid():
			snapshot = last
	_pull()
	redraw()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	if _feed != null and _feed.has_method(&"want_scoreboard"):
		var _told: Variant = _feed.call(&"want_scoreboard", false)
	closed.emit()


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible or not source.is_valid():
		return
	_since += delta
	if _since >= refresh_sec:
		_since = 0.0
		_pull()
		redraw()


func _pull() -> void:
	if source.is_valid():
		var snap: Variant = source.call()
		if snap is Dictionary:
			snapshot = snap


## The snapshot as it is drawn: after [member prepare].
func drawn_snapshot() -> Dictionary:
	if not prepare.is_valid():
		return snapshot
	var copy := snapshot.duplicate(true)
	prepare.call(copy)
	return copy


## The rows, decorated and sorted, as they will be drawn. Public so a suite can read them.
func rows(snap: Variant = null) -> Array:
	var from: Dictionary = snap if snap is Dictionary else drawn_snapshot()
	var out: Array = []
	var you: Variant = from.get("you", null)
	for raw in (from.get("players", []) as Array):
		if not (raw is Dictionary):
			continue
		var row := (raw as Dictionary).duplicate()
		if not row.has("you"):
			row["you"] = you != null and str(row.get("id", "")) == str(you)
		if decorate.is_valid():
			decorate.call(row)
		out.append(row)
	out.sort_custom(_before)
	return out


func _before(a: Dictionary, b: Dictionary) -> bool:
	if sort_with.is_valid():
		return bool(sort_with.call(a, b))
	var sa: Variant = a.get(sort_by, 0)
	var sb: Variant = b.get(sort_by, 0)
	if (sa is int or sa is float) and (sb is int or sb is float) and float(sa) != float(sb):
		return float(sa) > float(sb)
	return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0


func teams(snap: Variant = null) -> Array:
	var from: Dictionary = snap if snap is Dictionary else drawn_snapshot()
	var out: Array = []
	for t in (from.get("teams", []) as Array):
		if t is Dictionary:
			out.append(t)
	return out


func _signature(snap: Dictionary) -> int:
	var keys := 0
	for c in visible_columns():
		keys = keys * 31 + hash(c.get("key", ""))
	return [snap.hash(), keys, group_by, sort_by, side_by_side, title_text, spectators_title, kit.get_instance_id(), player_hidden.hash()].hash()


func redraw() -> void:
	if not _built:
		return
	var snap := drawn_snapshot()
	# A held board is redrawn every refresh_sec; rebuilding ~300 nodes for an unchanged snapshot cost ~50 ms of script each time, so skip when nothing visible changed.
	var sig := _signature(snap)
	if sig == _drawn_sig and _body.get_child_count() > 0:
		return
	_drawn_sig = sig
	_harvest_rows()
	GSMenuKit.clear(_body)
	_redraw_body(snap)
	# Rows nobody needed this time (a player left) are freed, so none outlive the board.
	for spare in _row_pool:
		spare.queue_free()
	_row_pool.clear()


func _redraw_body(snap: Dictionary) -> void:

	var header: Control = build_header.call(kit, snap) if build_header.is_valid() else _header(snap)
	GSMenuKit.clear(_head)
	if header != null:
		_head.add_child(header)

	var all := rows(snap)
	var team_list := teams(snap)
	if team_list.is_empty() or group_by == &"":
		_body.add_child(_team_block({}, all))
		return

	_placed.clear()
	_placed.resize(all.size())
	_blocks.clear()
	for t in team_list:
		_members.clear()
		var id: Variant = t.get("id", "")
		for i in range(all.size()):
			if _same_id(all[i].get(group_by, ""), id):
				_members.append(all[i])
				_placed[i] = true
		_blocks.append(_team_block(t, _members))
	_members.clear()

	if side_by_side and _blocks.size() == 2:
		var pair := HBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override(&"separation", 18)
		for b in _blocks:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_child(b)
		_body.add_child(pair)
	else:
		for b in _blocks:
			_body.add_child(b)
	_blocks.clear()

	_names.clear()
	for i in range(all.size()):
		if not _placed[i]:
			_names.append(_as_text(all[i].get("name", "?")))
	if not _names.is_empty():
		var who := ", ".join(_names)
		var line := kit.paragraph(spectators_title + SPECTATORS_GAP + who, kit.size_small, kit.palette.dim)
		line.name = "Spectators"
		_body.add_child(line)


## Whether a row's group value names team [param id]: what comparing their str() said (an int 1 and a String "1" match, an
## int 1 and a float 1.0 do not), without building either string in the usual case of two values of one type.
func _same_id(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == tb:
		if ta == TYPE_FLOAT and a != b:
			return is_equal_approx(a, b) and String.num(a) == String.num(b)
		return a == b
	if (ta == TYPE_STRING or ta == TYPE_STRING_NAME) and (tb == TYPE_STRING or tb == TYPE_STRING_NAME):
		return a == b
	return _as_text(a) == _as_text(b)


## [param value] as str() writes it.
func _as_text(value: Variant) -> String:
	if value is String:
		return value
	return "<null>" if value == null else format_value(_PLAIN, value, _PLAIN)


func _header(snap: Dictionary) -> Control:
	var p := kit.palette
	var server: Dictionary = snap.get("server", {})
	var col := VBoxContainer.new()
	col.name = "Header"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 2)

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := str(server.get("name", "")) if str(server.get("name", "")) != "" else title_text
	var title := kit.label(name, kit.size_title - 2, p.text, true)
	title.name = "ServerName"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	line.add_child(title)
	if server.has("players"):
		var count := "%d / %d" % [int(server.get("players", 0)), int(server.get("max", 0))] if int(server.get("max", 0)) > 0 \
			else str(int(server.get("players", 0)))
		line.add_child(kit.label(count + (" player" if count == "1" else " players"), kit.size_small, p.muted))
	col.add_child(line)

	var facts := PackedStringArray()
	for key in ["game", "map"]:
		if str(server.get(key, "")) != "":
			facts.append(str(server[key]))
	var extra: Variant = snap.get("header", {})
	if extra is Dictionary:
		for k in (extra as Dictionary):
			# An empty key is a fact with no label: "Round 3: the buses got everybody".
			var v := str((extra as Dictionary)[k])
			facts.append(v if str(k) == "" else "%s %s" % [str(k), v])
	if not facts.is_empty():
		var sub := kit.label("  ·  ".join(facts), kit.size_small, p.accent)
		sub.name = "Facts"
		col.add_child(sub)
	return col


func _team_block(team: Dictionary, members: Array) -> Control:
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override(&"separation", 4)
	block.name = "Team_%s" % str(team.get("id", "all")) if not team.is_empty() else "Players"

	if not team.is_empty():
		var head: Control = build_team_header.call(kit, team, members) if build_team_header.is_valid() \
			else _team_header(team, members)
		if head != null:
			block.add_child(head)

	block.add_child(_column_titles())
	var card := kit.card()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list := VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override(&"separation", 0)
	card.add_child(list)
	block.add_child(card)
	if members.is_empty():
		list.add_child(kit.paragraph("Nobody yet.", kit.size_small, kit.palette.dim))
	for r in members:
		var drawn: Control = build_row.call(kit, r, visible_columns()) if build_row.is_valid() else _stock_row(r)
		if drawn != null:
			list.add_child(drawn)
	return block


func _team_header(team: Dictionary, members: Array) -> Control:
	var p := kit.palette
	var colour: Variant = GSMenuPalette.parse_color(team.get("color", null))
	var tint: Color = colour if colour is Color else p.accent
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 10)
	var bar := ColorRect.new()
	bar.color = tint
	bar.custom_minimum_size = Vector2(4, 28)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(bar)
	var name := kit.label(str(team.get("name", "Team")), kit.size_heading, tint, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	line.add_child(kit.label("1 player" if members.size() == 1 else "%d players" % members.size(), kit.size_small, p.muted))
	if team.has("score"):
		line.add_child(kit.label(str(team["score"]), kit.size_title - 4, p.text, true))
	return line


func _column_titles() -> Control:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 12)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The card's own margin plus a row's, so a title sits over its column's numbers.
	pad.add_theme_constant_override(&"margin_left", 18 + ROW_PAD)
	pad.add_theme_constant_override(&"margin_right", 18 + ROW_PAD)
	pad.add_child(line)
	for c in visible_columns():
		var l := kit.label(str(c.get("title", "")), kit.size_small - 1, kit.palette.dim, true)
		_size_cell(l, c)
		line.add_child(l)
	return pad


func _row(row: Dictionary) -> Control:
	var you := bool(row.get("you", false))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta(&"gs_you", you)
	panel.add_theme_stylebox_override(&"panel", _row_box(you))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 12)
	panel.add_child(line)
	for c in visible_columns():
		var cell := _cell(c, row)
		_size_cell(cell, c)
		line.add_child(cell)
	return panel


## Takes the drawn stock rows out of their lists before the lists are freed, so the next draw refills them.
func _harvest_rows() -> void:
	if not reuse_rows:
		_live_rows.clear()
		return
	var sig := _columns_sig()
	if sig != _pool_sig:
		_pool_sig = sig
		_live_rows.clear()
		return
	for panel in _live_rows:
		if not is_instance_valid(panel) or panel.is_queued_for_deletion():
			continue
		var parent := panel.get_parent()
		if parent != null:
			parent.remove_child(panel)
		_row_pool.append(panel)
	_live_rows.clear()
	# Popped from the back, so reversed: rows keep their places when the order holds.
	_row_pool.reverse()


func _columns_sig() -> int:
	var keys := kit.get_instance_id()
	for c in visible_columns():
		keys = keys * 31 + hash(c.get("key", "")) * 7 + hash(c.get("kind", KIND_TEXT))
	return keys


func _stock_row(row: Dictionary) -> Control:
	if not reuse_rows:
		return _row(row)
	var panel: PanelContainer = null
	if not _row_pool.is_empty():
		panel = _row_pool.pop_back()
		_refill(panel, row)
	else:
		panel = _row(row)
	_live_rows.append(panel)
	return panel


func _row_box(you: bool) -> StyleBox:
	var p := kit.palette
	var none := Color(0, 0, 0, 0)
	return kit.box(p.accent_wash() if you else none, kit.radius_small, p.accent if you else none, 1 if you else 0, Vector4(ROW_PAD, 5, ROW_PAD, 5))


## Writes [param row] into a row [method _row] built earlier for the same columns: what it would have built, without new Controls for text.
func _refill(panel: PanelContainer, row: Dictionary) -> void:
	var you := bool(row.get("you", false))
	if bool(panel.get_meta(&"gs_you", false)) != you:
		panel.set_meta(&"gs_you", you)
		panel.add_theme_stylebox_override(&"panel", _row_box(you))
	var line := panel.get_child(0) as HBoxContainer
	var cols := visible_columns()
	for i in range(cols.size()):
		var c: Dictionary = cols[i]
		var old := line.get_child(i) as Control
		var kind := StringName(c.get("kind", KIND_TEXT))
		if kind == KIND_CUSTOM or kind == KIND_AVATAR or not (old is Label):
			var cell := _cell(c, row)
			_size_cell(cell, c)
			line.add_child(cell)
			line.move_child(cell, i)
			line.remove_child(old)
			old.queue_free()
			continue
		var l := old as Label
		l.text = _cell_text(c, row)
		l.add_theme_color_override(&"font_color", _cell_colour(c, row))


func _size_cell(cell: Control, column: Dictionary) -> void:
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := float(column.get("width", 1.0))
	if w <= 0.0:
		cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if cell.custom_minimum_size.x < 28.0:
			cell.custom_minimum_size.x = 28.0
		return
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_stretch_ratio = w
	if cell is Label:
		var kind := StringName(str(column.get("kind", KIND_TEXT)))
		var right := kind == KIND_NUMBER or kind == KIND_PING or kind == KIND_DURATION
		(cell as Label).horizontal_alignment = int(column.get("align",
			HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT))
		(cell as Label).clip_text = true
		(cell as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _cell(column: Dictionary, row: Dictionary) -> Control:
	var key: StringName = column.get("key", &"")
	var kind := StringName(str(column.get("kind", KIND_TEXT)))
	var value: Variant = row.get(key, row.get(String(key), null))

	match kind:
		KIND_CUSTOM:
			var built: Variant = (column["build"] as Callable).call(kit, row) if column.get("build") is Callable else null
			return built if built is Control else Control.new()
		KIND_AVATAR:
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(28, 28)
			if value is Texture2D:
				var pic := TextureRect.new()
				pic.texture = value
				pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				pic.custom_minimum_size = Vector2(28, 28)
				GSMenuKit.fill_parent(pic)
				holder.add_child(pic)
			return holder

	return kit.label(_cell_text(column, row), kit.size_body, _cell_colour(column, row), key == &"name")


func _cell_value(column: Dictionary, row: Dictionary) -> Variant:
	var key: StringName = column.get("key", &"")
	return row.get(key, row.get(String(key), null))


func _cell_text(column: Dictionary, row: Dictionary) -> String:
	var text := format_value(column, _cell_value(column, row), row)
	if column.get("key", &"") == &"name" and bool(row.get("bot", false)):
		text += BOT_TAG
	return text


func _cell_colour(column: Dictionary, row: Dictionary) -> Color:
	var key: StringName = column.get("key", &"")
	if StringName(column.get("kind", KIND_TEXT)) == KIND_PING:
		var value: Variant = _cell_value(column, row)
		return ping_colour(int(value) if value != null else -1)
	if key == &"name" and bool(row.get("you", false)):
		return kit.palette.accent
	return kit.palette.text


## The words a column shows for [param value]: its `format` Callable, or its kind's.
func format_value(column: Dictionary, value: Variant, row: Dictionary = {}) -> String:
	if column.get("format") is Callable:
		return str((column["format"] as Callable).call(value, row))
	match StringName(str(column.get("kind", KIND_TEXT))):
		KIND_PING:
			return "-" if value == null or int(value) < 0 else "%d" % int(value)
		KIND_DURATION:
			return duration(int(value) if value != null else -1)
		KIND_NUMBER:
			if value == null:
				return "-"
			return "%d" % int(value) if is_equal_approx(float(value), roundf(float(value))) else "%.1f" % float(value)
	return "" if value == null else str(value)


## 245 as "4:05", 3729 as "1:02:09", a negative as "-".
static func duration(seconds: int) -> String:
	if seconds < 0:
		return "-"
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	return "%d:%02d:%02d" % [h, m, s] if h > 0 else "%d:%02d" % [m, s]


## Good, fine, poor, bad: the HUD's ahead colour, the text, the warning, the danger.
func ping_colour(ms: int) -> Color:
	var p := kit.palette
	if ms < 0:
		return p.dim
	if ms < 60:
		return p.hud_ahead
	if ms < 120:
		return p.text
	if ms < 200:
		return p.warn
	return p.danger


func describe() -> Dictionary:
	return {
		"open": visible, "columns": columns.size(), "hidden": hidden_keys(), "rows": (snapshot.get("players", []) as Array).size(),
		"teams": teams().size(), "fed": _feed != null, "source": source.is_valid(), "reuse_rows": reuse_rows, "rows_kept": _live_rows.size(),
	}
