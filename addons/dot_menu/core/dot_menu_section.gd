class_name GSMenuSection
extends RefCounted

## A titled card of rows on a page: "Display", "Volume", "Movement". A section with nothing drawable in it is not drawn, so no bare heading sits over an empty
## card when every row names a setting this game did not declare.

## What [method GSMenuPage.section] finds it by. Defaults to the title, lowercased.
var id: StringName = &""

var title: String = ""

var rows: Array[GSMenuRow] = []

## BINDINGS: draw every row of this group of the menu's [GSMenuBindings] after [member rows].
## Empty draws none. What lets the Controls page grow a card per group without naming one.
var binding_group: String = ""


## DYNAMIC: `func() -> Array[GSMenuRow]`, asked each time the page is drawn and drawn after
## [member rows]. For a card whose rows exist only at runtime (the live scoreboard's columns).
var rows_from: Callable = Callable()


static func make(p_title: String, p_id: StringName = &"") -> GSMenuSection:
	var s := GSMenuSection.new()
	s.title = p_title
	s.id = p_id if p_id != &"" else StringName(p_title.to_snake_case())
	return s


func add(row: GSMenuRow) -> GSMenuSection:
	if row != null:
		rows.append(row)
	return self


## Puts [param row] before the row called [param before], or at the end when there is none.
func insert_before(before: StringName, row: GSMenuRow) -> GSMenuSection:
	for i in range(rows.size()):
		if rows[i].row_id() == before:
			rows.insert(i, row)
			return self
	rows.append(row)
	return self


func find_row(row_id: StringName) -> GSMenuRow:
	for r in rows:
		if r.row_id() == row_id:
			return r
	return null


func remove_row(row_id: StringName) -> bool:
	for i in range(rows.size()):
		if rows[i].row_id() == row_id:
			rows.remove_at(i)
			return true
	return false
