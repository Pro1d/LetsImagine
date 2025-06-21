class_name ScoreOverlay
extends Control

signal continue_clicked

@onready var _menu_button := %MenuButton as Button
@onready var _result_label := %ResultLabel as Label
@onready var _total_label := %TotalLabel as Label
@onready var _summary_label := %SummaryLabel as Label

func _ready() -> void:
	_menu_button.pressed.connect(continue_clicked.emit)

func set_victory(v: bool) -> void:
	_result_label.text = "Victory!" if v else "Defeat!"
	_result_label.label_settings.font_color = Color(0.478, 1, 0.635) if v else Color(0.82, 0.392, 0.392)

func commit_xp_gain(enemy: int, boss: int) -> void:
	var total := enemy + boss
	_display_xp(enemy, boss, total)
	var t := create_tween()
	t.tween_method(_display_total_xp, 0, total, 2.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.play()
	Config.give_xp(total)

func _display_xp(e: int, b: int, t: int) -> void:
	_summary_label.text = "Waves completed: %d exp\nBoss killed: %d exp" % [e, b]
	_display_total_xp(t)
func _display_total_xp(t: int) -> void:
	_total_label.text = "Total: %d exp" % [t]
