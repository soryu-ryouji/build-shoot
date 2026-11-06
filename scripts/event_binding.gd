extends RefCounted
class_name EventBinding

## UI 组件统一使用本类绑定事件。重复绑定会被拒绝，clear() 在退出场景树时调用。

var _connections: Array[Dictionary] = []


func bind(source: Signal, callback: Callable) -> void:
    if source.is_null() or not callback.is_valid():
        push_warning("EventBinding ignored an invalid signal or callback")
        return
    if source.is_connected(callback):
        return
    source.connect(callback)
    _connections.append({"signal": source, "callback": callback})


func unbind(source: Signal, callback: Callable) -> void:
    for index in range(_connections.size() - 1, -1, -1):
        var connection: Dictionary = _connections[index]
        if connection.signal == source and connection.callback == callback:
            if source.is_connected(callback):
                source.disconnect(callback)
            _connections.remove_at(index)


func clear() -> void:
    for connection in _connections:
        var source: Signal = connection.signal
        var callback: Callable = connection.callback
        if source.is_connected(callback):
            source.disconnect(callback)
    _connections.clear()


func count() -> int:
    return _connections.size()
