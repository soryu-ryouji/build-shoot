extends Control

## 可编辑建筑详情预置体。选中、属性、金币和语言均由 Events 驱动。

const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const ItemDefs = preload("res://scripts/item_defs.gd")
const EventBindingScript = preload("res://scripts/event_binding.gd")

const FIREPOWER_STATS := ["focus.damage", "focus.rate", "focus.range", "focus.pierce", "focus.shots"]
const FORTIFICATION_STATS := ["focus.hp", "focus.block", "focus.buff", "focus.energy", "focus.line", "focus.status"]
const ENERGY_STATS := ["focus.output", "focus.hp", "focus.energy_net", "focus.status"]

var game: Node
var building: Node = null

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var desc_label: Label = %DescLabel
@onready var power_label: Label = %PowerLabel
@onready var close_button: Button = %CloseButton
@onready var rule: ColorRect = %Rule
@onready var upgrade_effect: Label = %UpgradeEffect
@onready var upgrade_button: Button = %UpgradeButton
@onready var dismantle_button: Button = %DismantleButton
var stat_cells: Array[VBoxContainer] = []
var stat_names: Array[Label] = []
var stat_values: Array[Label] = []

var _accent := Palette.ACCENT
var _panel_style: StyleBoxFlat
var _events := EventBindingScript.new()


func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    _panel_style = StyleBoxFlat.new()
    _panel_style.bg_color = Color(Palette.PAPER, 0.985)
    _panel_style.border_color = _accent
    _panel_style.set_border_width_all(1)
    _panel_style.border_width_top = 3
    _panel_style.set_corner_radius_all(3)
    _panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
    _panel_style.shadow_size = 10
    _panel_style.shadow_offset = Vector2(0, 5)
    panel.add_theme_stylebox_override("panel", _panel_style)
    for cell in %StatsGrid.get_children():
        stat_cells.append(cell)
        stat_names.append(cell.get_node("Name"))
        stat_values.append(cell.get_node("Value"))

    close_button.add_theme_color_override("font_color", Palette.INK_MUTED)
    close_button.add_theme_color_override("font_hover_color", Palette.INK)
    close_button.add_theme_stylebox_override("normal", _button_style(Color(Palette.PAPER, 0.98), Color(Palette.INK, 0.22)))
    close_button.add_theme_stylebox_override("hover", _button_style(Color(Palette.ACCENT, 0.16), Palette.ACCENT))
    close_button.add_theme_stylebox_override("pressed", _button_style(Color(Palette.ACCENT, 0.28), Palette.ACCENT))
    upgrade_button.add_theme_color_override("font_color", Palette.INK)
    upgrade_button.add_theme_color_override("font_hover_color", Palette.INK)
    upgrade_button.add_theme_color_override("font_disabled_color", Palette.INK_MUTED)
    upgrade_button.add_theme_stylebox_override("normal", _button_style(Palette.ACCENT, Palette.ACCENT))
    upgrade_button.add_theme_stylebox_override("hover", _button_style(Palette.ACCENT.lightened(0.18), Palette.ACCENT))
    upgrade_button.add_theme_stylebox_override("pressed", _button_style(Palette.ACCENT.darkened(0.15), Palette.ACCENT))
    upgrade_button.add_theme_stylebox_override("disabled", _button_style(Color(0.72, 0.74, 0.72, 0.65), Color(0.30, 0.33, 0.34, 0.25)))
    dismantle_button.add_theme_color_override("font_color", Palette.DANGER)
    dismantle_button.add_theme_color_override("font_hover_color", Color.WHITE)
    dismantle_button.add_theme_stylebox_override("normal", _button_style(Color(Palette.PAPER, 0.98), Palette.DANGER.darkened(0.1)))
    dismantle_button.add_theme_stylebox_override("hover", _button_style(Palette.DANGER.lightened(0.65), Palette.DANGER))
    dismantle_button.add_theme_stylebox_override("pressed", _button_style(Color(0.18, 0.05, 0.07, 1.0), Palette.DANGER))

    _events.bind(Events.selection_changed, _on_selection_changed)
    _events.bind(Events.building_changed, _on_building_changed)
    _events.bind(Events.coins_changed, _on_coins_changed)
    _events.bind(Events.language_changed, _on_locale_changed)
    get_viewport().size_changed.connect(_layout)
    if is_instance_valid(Events.selected_building):
        show_building(Events.selected_building)
    _layout()


func _exit_tree() -> void:
    _events.clear()


func _on_selection_changed(target: Node) -> void:
    if target == null or not is_instance_valid(target):
        hide_panel()
    else:
        show_building(target)


func _on_building_changed(target: Node) -> void:
    if visible and target == building:
        _refresh_texts()
        _layout()


func _on_coins_changed(_current: int, _previous: int) -> void:
    if visible:
        _refresh_upgrade()


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(2)
    style.content_margin_left = 12
    style.content_margin_right = 12
    return style


func show_building(t: Node) -> void:
    building = t
    _accent = ItemDefs.category_color(String(t.category))
    _panel_style.border_color = _accent
    rule.color = _accent
    visible = true
    _refresh_texts()
    _layout()
    queue_redraw()


func refresh() -> void:
    if not visible:
        return
    _refresh_texts()
    _layout()


func _layout() -> void:
    if panel == null:
        return
    var available := ResponsiveLayout.focus_rect(self)
    # 先按侧栏宽度排版，让说明文字正确换行，再收紧高度并垂直居中。
    size = Vector2(available.size.x, size.y)
    var height := minf(panel.get_combined_minimum_size().y, available.size.y)
    size = Vector2(available.size.x, height)
    position = available.position + Vector2(0.0, (available.size.y - height) * 0.5)
    queue_redraw()


func hide_panel() -> void:
    visible = false
    building = null


func _refresh_texts() -> void:
    if building == null or not is_instance_valid(building):
        return
    title_label.text = building.get_display_name()
    if int(building.level) > 1:
        title_label.text += " " + I18n.t("focus.level", [int(building.level)])
    desc_label.text = building.get_display_desc()
    power_label.text = _power_text()
    power_label.add_theme_color_override("font_color", Palette.DANGER if not building.powered else Palette.INK_MUTED)
    _update_values()


func _power_text() -> String:
    if building == null or not is_instance_valid(building):
        return ""
    var text := ""
    if building.is_energy():
        text = I18n.t("focus.output_value", [int(building.energy_output)])
    else:
        text = I18n.t("focus.demand_value", [int(building.energy_demand)])
    if not building.powered:
        text += " · " + I18n.t("focus.paralyzed")
    return text


func _update_values() -> void:
    if building == null or not is_instance_valid(building):
        return

    var names: Array = []
    var values: Array = []
    var damage_boosted := false
    match String(building.category):
        ItemDefs.CATEGORY_FIREPOWER:
            var base_damage := int(building.damage)
            var effective_damage := int(building.get_effective_damage())
            damage_boosted = effective_damage != base_damage
            names = FIREPOWER_STATS
            values = [
                "%d → %d" % [base_damage, effective_damage] if damage_boosted else str(effective_damage),
                I18n.t("focus.rate_value", [String.num(float(building.get_effective_rate()), 2)]),
                str(int(building.attack_range)),
                "∞" if int(building.pierce) < 0 else str(int(building.pierce)),
                str(int(building.shots)),
            ]
        ItemDefs.CATEGORY_FORTIFICATION:
            names = FORTIFICATION_STATS
            values = [
                "%d/%d" % [int(ceil(float(building.hp))), int(building.max_hp)],
                I18n.t("focus.yes") if bool(building.blocks_enemies) else I18n.t("focus.no"),
                "×%d" % int(round(building.get_primary_aura_output_multiplier())) if int(building.buff_multiplier) > 1 else "—",
                str(int(building.energy_demand)),
                building.get_aura_coverage_text(),
                I18n.t("focus.powered") if bool(building.powered) else I18n.t("focus.paralyzed"),
            ]
        ItemDefs.CATEGORY_ENERGY:
            names = ENERGY_STATS
            values = [
                "+%d" % int(building.energy_output),
                "%d/%d" % [int(ceil(float(building.hp))), int(building.max_hp)],
                "+%d" % (int(building.energy_output) - int(building.energy_demand)),
                I18n.t("focus.powered") if bool(building.powered) else I18n.t("focus.paralyzed"),
            ]

    for i in stat_cells.size():
        var used := i < names.size()
        stat_cells[i].visible = used
        if used:
            stat_names[i].text = I18n.t(String(names[i]))
            stat_values[i].text = String(values[i])
            var value_color: Color = Palette.DANGER if values[i] == I18n.t("focus.paralyzed") else Palette.INK
            if i == 0 and damage_boosted:
                value_color = Palette.CYAN.darkened(0.25)
            stat_values[i].add_theme_color_override("font_color", value_color)

    power_label.text = _power_text()
    power_label.add_theme_color_override("font_color", Palette.DANGER if not building.powered else Palette.INK_MUTED)
    _refresh_upgrade()
    dismantle_button.text = I18n.t("focus.dismantle", [building.get_refund()])


func _refresh_upgrade() -> void:
    if building == null or not is_instance_valid(building):
        return
    var cost := int(building.get_upgrade_cost())
    var effect: Dictionary = building.get_upgrade_effect()
    if effect.is_empty() or cost < 0:
        upgrade_effect.text = I18n.t("focus.maxed")
        upgrade_button.text = "—"
        upgrade_button.disabled = true
        return
    upgrade_effect.text = _upgrade_effect_text(effect)
    upgrade_button.text = I18n.t("focus.upgrade", [cost])
    upgrade_button.disabled = Events.coins < cost


func _upgrade_effect_text(effect: Dictionary) -> String:
    if String(effect.get("kind", "add")) == "mult":
        return I18n.t("focus.upgrade_effect_mult", [int(effect.get("damage", 1)), int(effect.get("energy", 1))])
    if int(effect.get("damage", 0)) > 0:
        return I18n.t("focus.upgrade_effect_damage", [int(effect.get("damage", 0)), int(effect.get("energy", 0))])
    if int(effect.get("hp", 0)) > 0:
        return I18n.t("focus.upgrade_effect_hp", [int(effect.get("hp", 0)), int(effect.get("energy", 0))])
    if int(effect.get("output", 0)) > 0:
        return I18n.t("focus.upgrade_effect_output", [int(effect.get("output", 0))])
    return ""


func _on_locale_changed(_locale: String) -> void:
    if visible:
        _refresh_texts()
        _layout()
        queue_redraw()


func _on_close() -> void:
    game.clear_selection()


func _on_upgrade() -> void:
    game.upgrade_selected()


func _on_dismantle() -> void:
    game.dismantle_selected()
