require_relative "test_helper"
require "union_find"

class UnionFindTest < Minitest::Test
  def test_find_returns_self_initially
    uf = UnionFind.new(5)
    (0..4).each { |i| assert_equal i, uf.find(i) }
  end

  def test_union_merges_two_elements
    uf = UnionFind.new(3)
    uf.union(0, 1)
    assert_equal uf.find(0), uf.find(1)
    refute_equal uf.find(0), uf.find(2)
  end

  def test_transitive_union
    uf = UnionFind.new(4)
    uf.union(0, 1)
    uf.union(1, 2)
    assert_equal uf.find(0), uf.find(2)
    refute_equal uf.find(0), uf.find(3)
  end

  def test_union_is_idempotent
    uf = UnionFind.new(3)
    uf.union(0, 1)
    uf.union(0, 1)
    assert_equal uf.find(0), uf.find(1)
  end

  def test_single_element
    uf = UnionFind.new(1)
    assert_equal 0, uf.find(0)
  end

  def test_groups_returns_correct_grouping
    uf = UnionFind.new(5)
    uf.union(0, 2)
    uf.union(1, 3)

    groups = uf.groups
    assert_equal 3, groups.size

    # 0 and 2 in one group
    root_02 = uf.find(0)
    assert_includes groups[root_02], 0
    assert_includes groups[root_02], 2

    # 1 and 3 in one group
    root_13 = uf.find(1)
    assert_includes groups[root_13], 1
    assert_includes groups[root_13], 3

    # 4 alone
    assert_equal [4], groups[uf.find(4)]
  end

  def test_chain_union
    uf = UnionFind.new(5)
    uf.union(0, 1)
    uf.union(1, 2)
    uf.union(2, 3)
    uf.union(3, 4)

    root = uf.find(0)
    (1..4).each { |i| assert_equal root, uf.find(i) }
    assert_equal 1, uf.groups.size
  end

  # --- Dynamic growth (for streaming) ---

  def test_size
    uf = UnionFind.new(3)
    assert_equal 3, uf.size
  end

  def test_grow_adds_elements
    uf = UnionFind.new(2)
    uf.grow(5)
    assert_equal 5, uf.size
    # New elements are in their own groups
    (0..4).each { |i| assert_equal i, uf.find(i) }
  end

  def test_grow_preserves_existing_unions
    uf = UnionFind.new(3)
    uf.union(0, 1)
    uf.grow(5)
    assert_equal uf.find(0), uf.find(1)
    refute_equal uf.find(0), uf.find(3)
  end

  def test_grow_does_nothing_if_already_big_enough
    uf = UnionFind.new(5)
    uf.grow(3)
    assert_equal 5, uf.size
  end

  def test_union_after_grow
    uf = UnionFind.new(0)
    uf.grow(3)
    uf.union(0, 2)
    assert_equal uf.find(0), uf.find(2)
  end
end
