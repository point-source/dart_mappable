import 'list_copy_with.dart' show ItemCopyWith;
import 'mapper_utils.dart';

/// Interface used for [Map]s in chained copyWith methods
/// All methods return a new modified map and do not modify the original map
abstract class MapCopyWith<Result, Key, Value, Copy> {
  factory MapCopyWith(Map<Key, Value> value, ItemCopyWith<Copy, Value, Result> item,
      Then<Map<Key, Value>, Result> then) = _MapCopyWith;

  /// Access the copyWith interface for the value of [key]
  Copy? get(Key key);

  /// Returns a new map with [value] inserted at [key]
  Result put(Key key, Value v);

  /// Returns a new map with all entries inserted to the map
  Result putAll(Map<Key, Value> v);

  /// Returns a new map with the value at [key] replaced with a new value
  Result replace(Key key, Value v);

  /// Returns a new map without the value at [key]
  Result removeAt(Key key);

  /// Applies any transformer function on the value
  Result apply(Map<Key, Value> Function(Map<Key, Value>) transform);
}

class _MapCopyWith<Result, Key, Value, Copy> extends BaseCopyWith<Result, Map<Key, Value>, Map<Key, Value>>
    implements MapCopyWith<Result, Key, Value, Copy> {
  _MapCopyWith(Map<Key, Value> value, this._item, Then<Map<Key, Value>, Result> then)
      : super(value, $identity, then);
  final ItemCopyWith<Copy, Value, Result> _item;

  @override
  Copy? get(Key key) => $value[key] is Value
      ? _item($value[key] as Value, (v) => replace(key, v))
      : null;

  @override
  Result put(Key key, Value v) => putAll({key: v});

  @override
  Result putAll(Map<Key, Value> v) => $then({...$value, ...v});

  @override
  Result replace(Key key, Value v) => $then({...$value, key: v});

  @override
  Result removeAt(Key key) => $then({...$value}..remove(key));
}
