extends RefCounted
const GROUPS := {
	"Buceo": ["tank", "fins", "suit", "stabilizer"],
	"Pesca": ["reach", "reel", "net", "sonar", "lamp"],
	"Vehículos": ["scooter", "sub"],
	"Estación": ["bag", "aquarium", "lab", "traps"],
	"Especialidad": ["hunter", "scout"]
}
var main: Node
var cards := {}
var tabs: TabContainer
var records_view: RichTextLabel
var materials: Label

func setup(owner_node: Node) -> void:
	main = owner_node
	main.shop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main.shop.offset_left = -470
	main.shop.offset_right = 470
	main.shop.offset_top = -285
	main.shop.offset_bottom = 285
	main.shop.custom_minimum_size = Vector2(940, 570)
	main.get_node("HUD/Shop/Margin/Upgrades/Buttons").hide()
	materials = Label.new()
	materials.add_theme_font_size_override("font_size", 14)
	materials.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.upgrades_page.add_child(materials)
	main.upgrades_page.move_child(materials, 1)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.upgrades_page.add_child(tabs)
	main.upgrades_page.move_child(tabs, 2)
	for group in GROUPS:
		var scroll := ScrollContainer.new()
		scroll.name = group
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		scroll.add_child(list)
		if group == "Especialidad":
			var note := Label.new()
			note.text = "Elige una rama. La otra quedará bloqueada hasta el próximo prestigio."
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list.add_child(note)
		for id in GROUPS[group]:
			var panel := PanelContainer.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.055, 0.13, 0.18)
			style.content_margin_left = 14
			style.content_margin_right = 14
			style.content_margin_top = 10
			style.content_margin_bottom = 10
			style.set_corner_radius_all(6)
			panel.add_theme_stylebox_override("panel", style)
			list.add_child(panel)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 18)
			panel.add_child(row)
			var copy := VBoxContainer.new()
			copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(copy)
			var title := Label.new()
			title.add_theme_font_size_override("font_size", 19)
			copy.add_child(title)
			var detail := Label.new()
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.add_theme_font_size_override("font_size", 15)
			copy.add_child(detail)
			var reason := Label.new()
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reason.add_theme_font_size_override("font_size", 14)
			copy.add_child(reason)
			var buy := Button.new()
			buy.custom_minimum_size = Vector2(165, 68)
			buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			buy.pressed.connect(main.buy.bind(id))
			row.add_child(buy)
			cards[id] = {title = title, detail = detail, reason = reason, buy = buy}
	records_view = RichTextLabel.new()
	records_view.name = "Récords"
	records_view.bbcode_enabled = true
	records_view.add_theme_font_size_override("normal_font_size", 17)
	tabs.add_child(records_view)
	var legacy := VBoxContainer.new()
	legacy.name = "Prestigio"
	tabs.add_child(legacy)
	var note := Label.new()
	note.text = "Renacer\n\nReinicia monedas, equipo y materiales para ganar +25% permanente de venta.\nLos récords de pesca se conservan. Requiere traje nivel 25 y 100 000 monedas."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legacy.add_child(note)
	main.prestige_button.reparent(legacy)
	main.prestige_button.text = "Renacer (+25% de venta)"
	main.start_button.custom_minimum_size.y = 42

func refresh() -> void:
	main.upgrades_title.text = "Terminal de buceo · %d monedas" % main.coins
	main.start_button.text = "Iniciar día %d" % (main.day + 1)
	materials.text = "Materiales: "
	for i in main.mats.size():
		materials.text += "%s %d   " % [main.world.MATERIALS[i].name, main.mats[i]]
	for id in cards:
		var card: Dictionary = cards[id]
		var data: Dictionary = main.upgrades[id]
		card.title.text = "%s · nivel %d" % [data.name, main.lvl(id)]
		card.detail.text = str(data.desc)
		if id == "suit":
			card.detail.text = "+0,4 atm por nivel · soporte actual %.1f atm" % main.support()
		if id == "bag":
			card.detail.text += " · capacidad actual: %d peces" % main.bag_capacity()
		var reason: String = main.purchase_blocker(id)
		card.reason.text = reason if not reason.is_empty() else "Disponible"
		card.reason.modulate = main.AMBER if not reason.is_empty() else main.GREEN
		card.buy.disabled = not main.can_buy(id)
		card.buy.text = "Completado" if main.maxed(id) else "Mejorar\n%d monedas" % main.cost(id)
		var material: int = main.recipe_material(id)
		if material >= 0 and not main.maxed(id):
			card.detail.text += "\nCoste adicional: 1 %s" % main.world.MATERIALS[material].name
	main.prestige_button.disabled = main.lvl("suit") < 25 or main.coins < 100000
	records_view.text = "[b]Récords personales · se conservan al renacer[/b]\n\n"
	for id in range(13):
		var record: Dictionary = main.records.get(str(id), {})
		records_view.text += "%s: %s\n\n" % [main.SPECIES[id].name,
			"%.2f kg · mejor venta %d monedas · %d capturas" % [record.get("weight", 0), record.get("value", 0), record.get("count", 0)] if not record.is_empty() else "Sin capturas"]

