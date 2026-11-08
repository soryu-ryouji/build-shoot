extends PanelContainer

## 结算预置体：监听本局结果，按钮通过本地信号交给主场景执行。

signal restart_requested
signal menu_requested

const Palette = preload("res://scripts/palette.gd")
const ResponsiveLayout = preload("res://scripts/responsive_layout.gd")
const EventBindingScript = preload("res://scripts/event_binding.gd")

@onready var title_label: Label = %TitleLabel
@onready var detail_label: Label = %DetailLabel
var tutorial_result := false
var _events := EventBindingScript.new()


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    var style := StyleBoxFlat.new()
    style.bg_color = Color(Palette.PAPER, 0.98)
    style.border_color = Palette.ACCENT
    style.set_border_width_all(2)
    style.shadow_color = Color(0, 0, 0, 0.25)
    style.shadow_size = 12
    add_theme_stylebox_override("panel", style)
    _events.bind(Events.outcome_changed, _on_outcome_changed)
    _events.bind(Events.language_changed, _on_language_changed)
    get_viewport().size_changed.connect(_layout)
    _layout()


func _exit_tree() -> void:
    _events.clear()


func _on_outcome_changed(value: String) -> void:
    visible = value == "won" or value == "lost"
    if visible:
        _refresh_text(value)
        _layout()


func _on_language_changed(_locale: String) -> void:
    if visible:
        _refresh_text(Events.outcome)


func _refresh_text(value: String) -> void:
    if tutorial_result and value == "won":
        title_label.text = I18n.t("tutorial.complete.title")
        detail_label.text = I18n.t("tutorial.complete.detail")
        return
    title_label.text = I18n.t("result.won" if value == "won" else "result.lost")
    detail_label.text = I18n.t("result.won_detail" if value == "won" else "result.lost_detail")


func _layout() -> void:
    reset_size()
    var minimum := get_combined_minimum_size()
    var safe := ResponsiveLayout.safe_rect(self)
    var field := ResponsiveLayout.field_rect(self)
    var target := Vector2(minf(560.0, safe.size.x - 28.0), minimum.y)
    target.x = maxf(target.x, minf(minimum.x, safe.size.x - 28.0))
    size = target
    position = field.position + (field.size - target) * 0.5


func _on_restart() -> void:
    restart_requested.emit()


func _on_menu() -> void:
    menu_requested.emit()
