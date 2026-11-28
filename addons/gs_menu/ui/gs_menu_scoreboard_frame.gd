class_name GSMenuScoreboardFrame
extends CenterContainer

## The scoreboard's window: a header that stays and rows that scroll, kept to [constant GSMenuScoreboard.MAX_HEIGHT_FRACTION] of the view.
## [GSMenuScoreboard] draws into [member head] and [member body]; this only builds the window and sizes it. Freed with the board's children on a theme change.

var head: VBoxContainer = null
var body: VBoxContainer = null
var _window: PanelContainer = null
var _head_margin: MarginContainer = null
var _scroll: ScrollContainer = null
var _viewport: Viewport = null


func _init(kit: GSMenuKit) -> void:
	GSMenuKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_window = PanelContainer.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := kit.surface_box()
	s.bg_color = Color(kit.palette.surface, 0.9)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	_window.add_theme_stylebox_override(&"panel", s)
	add_child(_window)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override(&"separation", 12)
	_window.add_child(stack)
	head = VBoxContainer.new()
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head_margin = MarginContainer.new()
	_head_margin.name = "HeadMargin"
	_head_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_head_margin)
	_head_margin.add_child(head)
	# IGNORE: PASS still swallows clicks on HUD controls behind; the cost is no wheel scrolling.
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.focus_mode = Control.FOCUS_NONE
	stack.add_child(_scroll)
	body = VBoxContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 12)
	_scroll.add_child(body)
	body.minimum_size_changed.connect(_fit_scroll)
	head.minimum_size_changed.connect(_fit_scroll)
	_scroll.get_v_scroll_bar().visibility_changed.connect(_fit_bar)


func _enter_tree() -> void:
	var vp := get_viewport()
	if vp != _viewport and vp != null:
		_viewport = vp
		if not vp.size_changed.is_connected(fit):
			vp.size_changed.connect(fit)
	fit()


func _exit_tree() -> void:
	if _viewport != null and _viewport.size_changed.is_connected(fit):
		_viewport.size_changed.disconnect(fit)
	_viewport = null


## The header takes the scrollbar's width as a right margin so its columns meet the rows'.
func _fit_bar() -> void:
	var bar := _scroll.get_v_scroll_bar()
	_head_margin.add_theme_constant_override(&"margin_right", int(bar.get_combined_minimum_size().x) if bar.visible else 0)


## Sizes the window to the view: as wide as there is room for, and no taller than the cap.
func fit() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport_rect().size
	_window.custom_minimum_size = Vector2(clampf(view.x - 80.0, 360.0, 1080.0), 0)
	_fit_scroll()


## The panel stops at [constant GSMenuScoreboard.MAX_HEIGHT_FRACTION] of the view; the rows scroll, the header stays.
func _fit_scroll() -> void:
	if not is_inside_tree():
		return
	var room := get_viewport_rect().size.y * GSMenuScoreboard.MAX_HEIGHT_FRACTION - 40.0 - 12.0 - head.get_combined_minimum_size().y
	var want := minf(body.get_combined_minimum_size().y, maxf(room, 80.0))
	if not is_equal_approx(_scroll.custom_minimum_size.y, want):
		_scroll.custom_minimum_size.y = want
