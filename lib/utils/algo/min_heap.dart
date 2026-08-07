/// An item wrapper for the Min-Heap storing the data payload and its numerical priority.
/// Lower priority numbers indicate higher urgency (e.g., Priority 1 = Critical/Emergency).
class HeapNode<T> {
  final T data;
  final double priority;

  HeapNode({
    required this.data,
    required this.priority,
  });
}

/// Generic Min-Heap Priority Queue Algorithm implementation for ResQ
class MinHeap<T> {
  final List<HeapNode<T>> _heap = [];

  /// Get current number of items in the heap
  int get size => _heap.length;

  /// Check if the heap is empty
  bool get isEmpty => _heap.isEmpty;

  /// Look at the top priority item without removing it ($O(1)$)
  T? peek() {
    if (_heap.isEmpty) return null;
    return _heap[0].data;
  }

  /// Inserts a new element into the heap ($O(\log N)$)
  void insert(T data, double priority) {
    final node = HeapNode(data: data, priority: priority);
    _heap.add(node);
    _bubbleUp(_heap.length - 1);
  }

  /// Removes and returns the highest priority element (root node) ($O(\log N)$)
  T? extractMin() {
    if (_heap.isEmpty) return null;

    final minItem = _heap[0].data;
    final lastItem = _heap.removeLast();

    if (_heap.isNotEmpty) {
      _heap[0] = lastItem;
      _sinkDown(0);
    }

    return minItem;
  }

  /// Returns a sorted List representation of all items in priority order without mutating the heap
  List<T> toSortedList() {
    final tempHeap = List<HeapNode<T>>.from(_heap);
    final sortedList = <T>[];

    while (_heap.isNotEmpty) {
      final min = extractMin();
      if (min != null) {
        sortedList.add(min);
      }
    }

    // Restore original heap state
    _heap.addAll(tempHeap);
    return sortedList;
  }

  // ----------------------------------------------------
  // HEAP HELPER METHODS (TREE INDEXING & REBALANCING)
  // ----------------------------------------------------

  int _parentIndex(int i) => (i - 1) ~/ 2;
  int _leftChildIndex(int i) => 2 * i + 1;
  int _rightChildIndex(int i) => 2 * i + 2;

  void _swap(int i, int j) {
    final temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }

  /// Rebalances moving up from a child node after insertion
  void _bubbleUp(int index) {
    int currentIndex = index;

    while (currentIndex > 0) {
      int parent = _parentIndex(currentIndex);

      if (_heap[currentIndex].priority < _heap[parent].priority) {
        _swap(currentIndex, parent);
        currentIndex = parent;
      } else {
        break;
      }
    }
  }

  /// Rebalances moving down from root node after extraction
  void _sinkDown(int index) {
    int currentIndex = index;

    while (_leftChildIndex(currentIndex) < _heap.length) {
      int smallestChildIndex = _leftChildIndex(currentIndex);
      int rightChild = _rightChildIndex(currentIndex);

      if (rightChild < _heap.length &&
          _heap[rightChild].priority < _heap[smallestChildIndex].priority) {
        smallestChildIndex = rightChild;
      }

      if (_heap[smallestChildIndex].priority < _heap[currentIndex].priority) {
        _swap(currentIndex, smallestChildIndex);
        currentIndex = smallestChildIndex;
      } else {
        break;
      }
    }
  }
}