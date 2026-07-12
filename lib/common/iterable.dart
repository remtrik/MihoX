extension IterableExt<T> on Iterable<T> {
  Iterable<T> separated(T separator) sync* {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return;

    yield iterator.current;

    while (iterator.moveNext()) {
      yield separator;
      yield iterator.current;
    }
  }

  Iterable<List<T>> chunks(int size) sync* {
    final iterator = this.iterator;
    while (iterator.moveNext()) {
      final chunk = [iterator.current];
      for (var i = 1; i < size && iterator.moveNext(); i++) {
        chunk.add(iterator.current);
      }
      yield chunk;
    }
  }

  Iterable<T> fill(
    int length, {
    required T Function(int count) filler,
  }) sync* {
    var count = 0;
    for (final item in this) {
      yield item;
      count++;
      if (count >= length) return;
    }
    while (count < length) {
      yield filler(count);
      count++;
    }
  }

  Iterable<T> takeLast({int count = 50}) {
    if (count <= 0) return const Iterable.empty();
    return count >= length ? this : toList().skip(length - count);
  }
}

extension ListExt<T> on List<T> {
  void truncate(int maxLength) {
    assert(maxLength > 0);
    if (length > maxLength) {
      removeRange(0, length - maxLength);
    }
  }

  List<T> intersection(List<T> list) {
    final set = list.toSet();
    return where(set.contains).toList();
  }

  List<List<T>> batch(int maxConcurrent) {
    final res = <List<T>>[];
    for (var i = 0; i < length; i += maxConcurrent) {
      res.add(sublist(i, (i + maxConcurrent).clamp(0, length)));
    }
    return res;
  }

  List<T> safeSublist(int start) {
    if (start <= 0) return this;
    if (start > length) return [];
    return sublist(start);
  }
}

extension DoubleListExt on List<double> {
  int findInterval(num target) {
    if (isEmpty) return -1;
    if (target < first) return -1;
    if (target >= last) return length - 1;

    var left = 0;
    var right = length - 1;

    while (left <= right) {
      final mid = left + (right - left) ~/ 2;

      if (mid == length - 1 ||
          (this[mid] <= target && target < this[mid + 1])) {
        return mid;
      } else if (target < this[mid]) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    return -1;
  }
}

extension MapExt<K, V> on Map<K, V> {
  V? updateCacheValue(K key, V Function() callback) => this[key] ??= callback();
}
