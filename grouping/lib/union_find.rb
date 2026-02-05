# frozen_string_literal: true

# Union-Find (also called "Disjoint Set Union") is a data structure that
# tracks a collection of elements split into non-overlapping groups.
#
# Think of it like this: each CSV row starts in its own group. When we
# discover that two rows share an email or phone, we merge (union) their
# groups. Later, we can ask "which group does row X belong to?" (find)
# and all rows that were transitively linked will share the same group.
#
# Two optimizations make this nearly O(1) per operation:
#   - Path compression: when we look up a row's group, we shortcut future
#     lookups by pointing directly to the root.
#   - Union by rank: when merging two groups, we attach the shorter tree
#     under the taller one to keep things balanced.
#
# For more background, see: https://en.wikipedia.org/wiki/Disjoint-set_data_structure
class UnionFind
  # Creates n elements (0 through n-1), each in its own group.
  # @parent tracks who each element's "leader" is (initially itself).
  # @rank is a rough measure of tree height, used to keep trees balanced.
  def initialize(n)
    @parent = Array.new(n) { |i| i }
    @rank = Array.new(n, 0)
  end

  # Returns the current number of elements.
  def size
    @parent.length
  end

  # Grows the structure to hold at least new_size elements.
  # New elements start in their own group. Used by streaming matchers
  # that don't know the total row count upfront.
  def grow(new_size)
    return if new_size <= @parent.length

    old_size = @parent.length
    @parent.concat(Array.new(new_size - old_size) { |i| old_size + i })
    @rank.concat(Array.new(new_size - old_size, 0))
  end

  # Returns the root representative for element x.
  # Uses iterative path compression: first walks up to find the root,
  # then walks the chain again to point every node directly at the root.
  # Iterative (not recursive) to avoid stack overflow on very large datasets.
  def find(x)
    root = x
    root = @parent[root] while @parent[root] != root

    # Path compression: flatten the chain so future lookups are O(1)
    while @parent[x] != root
      @parent[x], x = root, @parent[x]
    end

    root
  end

  # Merges the groups containing x and y into a single group.
  # Uses union by rank: the shorter tree goes under the taller one.
  # If they're the same height, we pick one and bump its rank.
  def union(x, y)
    root_x = find(x)
    root_y = find(y)
    return if root_x == root_y

    if @rank[root_x] < @rank[root_y]
      @parent[root_x] = root_y
    elsif @rank[root_x] > @rank[root_y]
      @parent[root_y] = root_x
    else
      @parent[root_y] = root_x
      @rank[root_x] += 1
    end
  end

  # Returns a Hash mapping each group's root index to an Array of member
  # indices. Used at the end to convert the internal structure into
  # something we can assign PersonIDs from.
  #
  # Example: { 0 => [0, 2, 5], 1 => [1, 3], 4 => [4] }
  def groups
    result = Hash.new { |h, k| h[k] = [] }
    @parent.length.times { |i| result[find(i)] << i }
    result
  end
end
