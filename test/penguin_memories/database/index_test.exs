defmodule PenguinMemories.Database.IndexTest do
  use ExUnit.Case, async: true
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Index
  import Mox

  # Can be any valid type
  @dummy_type PenguinMemories.Photos.Album

  defp reverse_map(map) do
    Enum.reduce(map, %{}, fn {k, vs}, acc ->
      Enum.reduce(vs, acc, fn v, acc ->
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        update_in(acc[v], fn
          nil -> MapSet.new([k])
          set -> MapSet.put(set, k)
        end)
      end)
    end)
  end

  defp map_fetch(map, id) do
    Map.get(map, id, MapSet.new())
  end

  describe "test walk_tree/5" do
    test "single item" do
      # 1 object with no parents or children.
      parent_data = %{
        1 => []
      }

      child_data = reverse_map(parent_data)

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)

      {:ok, parents, children} =
        Index.walk_tree(1, %{}, %{}, @dummy_type, PenguinMemories.Database.Impl.Index.Mock)

      assert parents == %{
               1 => []
             }

      assert children == %{
               1 => []
             }
    end

    test "simple tree from child of child" do
      # Child, parent, grandparent.
      parent_data = %{
        1 => [],
        2 => [1],
        3 => [2]
      }

      child_data = reverse_map(parent_data)

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)

      {:ok, parents, children} =
        Index.walk_tree(3, %{}, %{}, @dummy_type, PenguinMemories.Database.Impl.Index.Mock)

      assert parents == %{
               1 => [],
               2 => [1],
               3 => [2]
             }

      assert children == %{
               1 => [2],
               2 => [3],
               3 => []
             }
    end

    test "simple tree from parent of parent" do
      # Child, parent, grandparent.
      parent_data = %{
        1 => [],
        2 => [1],
        3 => [2]
      }

      child_data = reverse_map(parent_data)

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)

      {:ok, parents, children} =
        Index.walk_tree(1, %{}, %{}, @dummy_type, PenguinMemories.Database.Impl.Index.Mock)

      assert parents == %{
               1 => [],
               2 => [1],
               3 => [2]
             }

      assert children == %{
               1 => [2],
               2 => [3],
               3 => []
             }
    end

    test "loop" do
      # Grandparent's parent is child.
      parent_data = %{
        1 => [3],
        2 => [1],
        3 => [2]
      }

      child_data = reverse_map(parent_data)

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)

      {:ok, parents, children} =
        Index.walk_tree(3, %{}, %{}, @dummy_type, PenguinMemories.Database.Impl.Index.Mock)

      assert parents == %{
               1 => [3],
               2 => [1],
               3 => [2]
             }

      assert children == %{
               1 => [2],
               2 => [3],
               3 => [1]
             }
    end

    test "multiple parents" do
      # Child has two parents and four grandparents.
      parent_data = %{
        1 => [],
        2 => [],
        3 => [],
        4 => [],
        5 => [1, 2],
        6 => [3, 4],
        7 => [5, 6]
      }

      child_data = reverse_map(parent_data)

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)

      {:ok, parents, children} =
        Index.walk_tree(7, %{}, %{}, @dummy_type, PenguinMemories.Database.Impl.Index.Mock)

      assert parents == %{
               1 => [],
               2 => [],
               3 => [],
               4 => [],
               5 => [2, 1],
               6 => [4, 3],
               7 => [6, 5]
             }

      assert children == %{
               1 => [5],
               2 => [5],
               3 => [6],
               4 => [6],
               5 => [7],
               6 => [7],
               7 => []
             }
    end

    test "shared path" do
      # Two siblings have a child.
      parent_data = %{
        1 => [],
        2 => [1],
        3 => [1],
        4 => [2, 3]
      }

      child_data = reverse_map(parent_data)

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)

      {:ok, parents, children} =
        Index.walk_tree(4, %{}, %{}, @dummy_type, PenguinMemories.Database.Impl.Index.Mock)

      assert parents == %{
               1 => [],
               2 => [1],
               3 => [1],
               4 => [3, 2]
             }

      assert children == %{
               1 => [3, 2],
               2 => [4],
               3 => [4],
               4 => []
             }
    end

    test "shared path different position" do
      # Object is parent and grandparent.
      # This is likely to get confusing rather quickly.
      parent_data = %{
        1 => [],
        2 => [1],
        3 => [2, 1]
      }

      child_data = reverse_map(parent_data)

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)

      {:ok, parents, children} =
        Index.walk_tree(3, %{}, %{}, @dummy_type, PenguinMemories.Database.Impl.Index.Mock)

      assert parents == %{
               1 => [],
               2 => [1],
               3 => [1, 2]
             }

      assert children == %{
               1 => [3, 2],
               2 => [3],
               3 => []
             }
    end
  end

  describe "generate_index/5" do
    test "single item" do
      # 1 object with no parents or children.
      parents = %{
        1 => []
      }

      children = %{
        1 => []
      }

      {:ok, index} =
        Index.generate_index(1, 0, parents, children, %{}, do_parents: true, do_children: true)

      assert index == %{1 => 0}
    end

    test "simple tree from child of child" do
      # Child, parent, grandparent.
      parents = %{
        1 => [],
        2 => [1],
        3 => [2]
      }

      children = %{
        1 => [2],
        2 => [3],
        3 => []
      }

      {:ok, index} =
        Index.generate_index(3, 0, parents, children, %{}, do_parents: true, do_children: true)

      assert index == %{3 => 0, 2 => 1, 1 => 2}
    end

    test "simple tree from parent of parent" do
      # Child, parent, grandparent.
      parents = %{
        1 => [],
        2 => [1],
        3 => [2]
      }

      children = %{
        1 => [2],
        2 => [3],
        3 => []
      }

      {:ok, index} =
        Index.generate_index(1, 0, parents, children, %{}, do_parents: true, do_children: true)

      assert index == %{3 => -2, 2 => -1, 1 => 0}
    end

    test "loop" do
      # Grandparent's parent is child.
      parents = %{
        1 => [3],
        2 => [1],
        3 => [2]
      }

      children = %{
        1 => [2],
        2 => [3],
        3 => [1]
      }

      {:ok, index} =
        Index.generate_index(3, 0, parents, children, %{}, do_parents: true, do_children: true)

      assert index == %{3 => 0, 2 => 1, 1 => 2}
    end

    test "multiple parents" do
      # Child has two parents and four grandparents.
      parents = %{
        1 => [],
        2 => [],
        3 => [],
        4 => [],
        5 => [2, 1],
        6 => [4, 3],
        7 => [6, 5]
      }

      children = %{
        1 => [5],
        2 => [5],
        3 => [6],
        4 => [6],
        5 => [7],
        6 => [7],
        7 => []
      }

      {:ok, index} =
        Index.generate_index(7, 0, parents, children, %{}, do_parents: true, do_children: true)

      assert index == %{7 => 0, 5 => 1, 6 => 1, 1 => 2, 2 => 2, 3 => 2, 4 => 2}
    end

    test "shared path" do
      # Two siblings have a child.
      parents = %{
        1 => [],
        2 => [1],
        3 => [1],
        4 => [3, 2]
      }

      children = %{
        1 => [3, 2],
        2 => [4],
        3 => [4],
        4 => []
      }

      {:ok, index} =
        Index.generate_index(4, 0, parents, children, %{}, do_parents: true, do_children: true)

      assert index == %{4 => 0, 2 => 1, 3 => 1, 1 => 2}
    end

    test "shared path different position" do
      # Object is parent and grandparent.
      # This is likely to get confusing rather quickly.
      parents = %{
        1 => [],
        2 => [1],
        3 => [1, 2]
      }

      children = %{
        1 => [3, 2],
        2 => [3],
        3 => []
      }

      {:ok, index} =
        Index.generate_index(3, 0, parents, children, %{}, do_parents: true, do_children: true)

      assert index == %{1 => 1, 2 => 1, 3 => 0}
    end
  end

  describe "update_index/4" do
    test "simple update" do
      old_index = %{1 => MapSet.new([{1, 1}, {5, 1}])}
      new_index = %{2 => 1, 1 => 2}

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_index, fn id, _ -> map_fetch(old_index, id) end)
      |> expect(:set_done, 1, fn _, _ -> :ok end)
      |> expect(:bulk_update_index, 1, fn id, to_delete, to_upsert, _ ->
        assert id == 1
        assert to_delete == [5]
        assert MapSet.new(to_upsert) == MapSet.new([{2, 1}, {1, 2}])
        :ok
      end)

      :ok =
        Index.update_index(1, new_index, @dummy_type, PenguinMemories.Database.Impl.Index.Mock)

      verify!()
    end
  end

  describe "fix_index_tree/4" do
    test "multiple item parents" do
      # Node, parent, grandparent.
      parent_data = %{
        1 => [],
        2 => [1],
        3 => [2]
      }

      child_data = reverse_map(parent_data)

      index = %{
        1 => MapSet.new([{1, 98}]),
        2 => MapSet.new([{1, 99}]),
        3 => MapSet.new([])
      }

      {:ok, upsert_table} = Agent.start(fn -> %{} end)

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)
      |> stub(:get_index, fn id, _ -> map_fetch(index, id) end)
      |> expect(:set_done, 3, fn _, _ -> :ok end)
      |> stub(:bulk_update_index, fn id, _to_delete, to_upsert, _ ->
        Agent.update(upsert_table, fn acc ->
          Enum.reduce(to_upsert, acc, fn {ref_id, position}, acc ->
            Map.update(
              acc,
              id,
              MapSet.new([{ref_id, position}]),
              &MapSet.put(&1, {ref_id, position})
            )
          end)
        end)

        :ok
      end)

      {:ok, _, _} =
        Index.fix_index_tree(3, %{}, %{}, @dummy_type, PenguinMemories.Database.Impl.Index.Mock)

      assert Agent.get(upsert_table, & &1) == %{
               1 => MapSet.new([{1, 0}, {2, -1}, {3, -2}]),
               2 => MapSet.new([{1, 1}, {2, 0}, {3, -1}]),
               3 => MapSet.new([{3, 0}, {2, 1}, {1, 2}])
             }

      verify!()
    end
  end
end
