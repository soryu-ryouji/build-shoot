# UI 预置体与事件中心

## 目录

主要界面均可在 Godot 编辑器中直接打开并调整：

| 组件 | 场景 | 绑定/交互脚本 |
| --- | --- | --- |
| 左上角菜单与战场提示 | `scenes/ui/hud.tscn` | `scripts/hud.gd` |
| 底部书签建造栏及金币/能源 | `scenes/ui/shop_bar.tscn` | `scripts/shop_bar.gd` |
| 道具卡 | `scenes/ui/item_card.tscn` | `scripts/item_card.gd` |
| 指针拖拽建筑实体预览 | `scenes/ui/drag_preview.tscn` | `scripts/drag_preview.gd` |
| 建筑详情 | `scenes/ui/focus_panel.tscn` | `scripts/focus_panel.gd` |
| 设置 | `scenes/ui/settings_panel.tscn` | `scripts/settings_panel.gd` |
| 胜负结算 | `scenes/ui/result_panel.tscn` | `scripts/result_panel.gd` |
| 主菜单 | `scenes/main_menu.tscn` | `scripts/main_menu.gd` |

需要被脚本引用的节点已启用 **Scene Unique Name**，脚本使用 `%NodeName` 获取。修改显示文本、字体、颜色、容器间距、最小尺寸和子节点顺序，通常不需要改脚本。

`ShopBar` 在运行时按当前标签实例化 `ItemCard.tscn`。修改道具卡预置体会同时应用到所有类别。

主要区域的自适应位置仍集中在：

- `scripts/responsive_layout.gd`：左上角菜单、战场、底部商店和详情的可用矩形。
- `scripts/ui_metrics.gd`：横屏基准、触控尺寸和全局 UI 尺寸。

## 事件中心

`Events` 是 `scripts/event_center.gd` 注册的全局 Autoload，位于其他自动加载脚本之前。

它提供两层接口：

1. **具体信号**：UI 推荐使用，参数明确，例如 `coins_changed(current, previous)`。
2. **`event_published(event_name, payload)`**：用于日志、调试和通用扩展，所有发布方法都会同步写入该通道。

事件中心还缓存金币、能源、基地生命、巢穴数量、选中建筑和胜负等最新状态。因此晚加载的 UI 可以在 `_ready()` 中直接读取 `Events.coins` 等值完成首次渲染，不需要等待下一次变化。

每局开始由主场景调用 `Events.reset_session()`，避免场景重载后沿用上一局缓存。

### 已有信号

| 信号 | 用途 |
| --- | --- |
| `coins_changed(current, previous)` | 金币、购买状态、升级按钮 |
| `power_changed(demand, supply, offline)` | 能源信息 |
| `base_health_changed(current, maximum)` | 基地生命 |
| `nest_count_changed(alive)` | 剩余巢穴 |
| `destroyed_changed(count)` | 击碎统计 |
| `selection_changed(building)` | 打开或关闭建筑详情 |
| `building_changed(building)` | 属性、射击次数、供电、增益变化 |
| `placement_changed(active, item_id)` | 部署状态 |
| `outcome_changed(outcome)` | 胜负结算 |
| `language_changed(locale)` | UI 文案语言 |
| `setting_changed(option, value)` | 设置项 |
| `toast_requested(text, color)` | 短时提示 |

## 在 UI 中绑定

所有需要监听事件的 UI 都使用 `scripts/event_binding.gd`。它负责防止重复连接、记录连接，并在组件退出时集中解绑。

```gdscript
const EventBindingScript = preload("res://scripts/event_binding.gd")
var _events := EventBindingScript.new()

func _ready() -> void:
    _events.bind(Events.coins_changed, _on_coins_changed)
    _events.bind(Events.language_changed, _on_language_changed)
    # 晚加入时先读取缓存。
    _on_coins_changed(Events.coins, Events.coins)

func _on_coins_changed(current: int, _previous: int) -> void:
    %CoinsLabel.text = I18n.t("hud.coins", [current])

func _exit_tree() -> void:
    _events.clear()
```

也可使用 `unbind(signal, callback)` 单独解绑，或用 `count()` 检查当前管理的连接数。

## 发布状态

业务逻辑修改自己的状态后，调用对应发布方法：

```gdscript
Events.set_coins(coins, previous)
Events.set_power(demand, supply, offline)
Events.select_building(building)
Events.update_building(building)
Events.set_outcome("won")
```

项目的 `Main.coins` 和 `Main.outcome` 已通过属性 setter 自动发布，因此原有 `coins += 30`、`outcome = "won"` 也会触发 UI 更新。

不要在 UI 中反向修改金币、供电或建筑属性。按钮只调用主逻辑操作，主逻辑完成状态变更后发布事件，UI 再响应结果。

## 验证

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . res://tools/event_center_test.tscn
```

专项测试覆盖：重复绑定防护、具体信号参数、通用发布通道、状态缓存、晚加载 HUD、事件响应、绑定清理、全部预置体加载，以及结算结果事件。
