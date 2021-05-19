defmodule PenguinMemories.Database.IndexTest do
  defmodule MapSetStore do
    def init(state \\ %{}) do
      {:ok, state}
    end

    def handle_call({:put, id, ref_id, position}, _from, state) do
      state =
        Map.update(
          state,
          id,
          MapSet.new([{ref_id, position}]),
          fn mapset -> MapSet.put(mapset, {ref_id, position}) end
        )

      {:reply, :ok, state}
    end

    def handle_call(:get, _from, state) do
      {:reply, state, state}
    end
  end

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

  describe "generate_index/5" do
    test "single item" do
      # 1 object with no parents or children.
      parent_data = %{
        1 => []
      }

      child_data = reverse_map(parent_data)

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)

      seen = MapSet.new()
      cache = %{}

      {seen, cache, index} = Index.generate_index(1, 0, @dummy_type, seen, cache)

      assert seen == MapSet.new([1])

      assert cache == %{
               1 => MapSet.new([{1, 0}])
             }

      assert index == MapSet.new([{1, 0}])
    end

    test "simple tree" do
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

      seen = MapSet.new()
      cache = %{}

      {seen, cache, index} = Index.generate_index(3, 0, @dummy_type, seen, cache)

      assert seen == MapSet.new([1, 2, 3])

      assert cache == %{
               1 => MapSet.new([{1, 0}]),
               2 => MapSet.new([{2, 0}, {1, 1}]),
               3 => MapSet.new([{3, 0}, {2, 1}, {1, 2}])
             }

      assert index == MapSet.new([{3, 0}, {2, 1}, {1, 2}])
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

      seen = MapSet.new()
      cache = %{}

      {seen, cache, index} = Index.generate_index(3, 0, @dummy_type, seen, cache)

      assert seen == MapSet.new([1, 2, 3])

      assert cache == %{
               1 => MapSet.new([{1, 0}]),
               2 => MapSet.new([{2, 0}, {1, 1}]),
               3 => MapSet.new([{3, 0}, {2, 1}, {1, 2}])
             }

      assert index == MapSet.new([{3, 0}, {2, 1}, {1, 2}])
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

      seen = MapSet.new()
      cache = %{}

      {seen, cache, index} = Index.generate_index(7, 0, @dummy_type, seen, cache)

      assert seen == MapSet.new([1, 2, 3, 4, 5, 6, 7])

      assert cache == %{
               1 => MapSet.new([{1, 0}]),
               2 => MapSet.new([{2, 0}]),
               3 => MapSet.new([{3, 0}]),
               4 => MapSet.new([{4, 0}]),
               5 => MapSet.new([{5, 0}, {1, 1}, {2, 1}]),
               6 => MapSet.new([{6, 0}, {3, 1}, {4, 1}]),
               7 => MapSet.new([{7, 0}, {5, 1}, {6, 1}, {1, 2}, {2, 2}, {3, 2}, {4, 2}])
             }

      assert index == MapSet.new([{7, 0}, {5, 1}, {6, 1}, {1, 2}, {2, 2}, {3, 2}, {4, 2}])
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

      seen = MapSet.new()
      cache = %{}

      {seen, cache, index} = Index.generate_index(4, 0, @dummy_type, seen, cache)

      assert seen == MapSet.new([1, 2, 3, 4])

      assert cache == %{
               1 => MapSet.new([{1, 0}]),
               2 => MapSet.new([{2, 0}, {1, 1}]),
               3 => MapSet.new([{3, 0}, {1, 1}]),
               4 => MapSet.new([{4, 0}, {2, 1}, {3, 1}, {1, 2}])
             }

      assert index == MapSet.new([{4, 0}, {2, 1}, {3, 1}, {4, 0}, {1, 2}])
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

      seen = MapSet.new()
      cache = %{}

      {seen, cache, index} = Index.generate_index(3, 0, @dummy_type, seen, cache)

      assert seen == MapSet.new([1, 2, 3])

      assert cache == %{
               1 => MapSet.new([{1, 0}]),
               2 => MapSet.new([{2, 0}, {1, 1}]),
               3 => MapSet.new([{3, 0}, {1, 1}, {2, 1}, {1, 2}])
             }

      assert index == MapSet.new([{1, 2}, {1, 1}, {2, 1}, {3, 0}])
    end
  end

  describe "fix_index_tree/4" do
    test "single item" do
      # 1 object with no parents or children.
      parent_data = %{
        1 => []
      }

      child_data = reverse_map(parent_data)

      index = %{
        1 => MapSet.new([{1, 1}])
      }

      {:ok, delete_table} = GenServer.start(MapSetStore, %{})
      {:ok, create_table} = GenServer.start(MapSetStore, %{})

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)
      |> stub(:get_index, fn id, _ -> map_fetch(index, id) end)
      |> expect(:delete_index, 1, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(delete_table, {:put, id, ref_id, position})
        :ok
      end)
      |> expect(:create_index, 1, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(create_table, {:put, id, ref_id, position})
        :ok
      end)

      :ok = Index.fix_index_tree(1, @dummy_type)

      assert GenServer.call(delete_table, :get) == %{
               1 => MapSet.new([{1, 1}])
             }

      assert GenServer.call(create_table, :get) == %{
               1 => MapSet.new([{1, 0}])
             }

      verify!()
    end

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

      {:ok, delete_table} = GenServer.start(MapSetStore, %{})
      {:ok, create_table} = GenServer.start(MapSetStore, %{})

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)
      |> stub(:get_index, fn id, _ -> map_fetch(index, id) end)
      |> expect(:delete_index, 2, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(delete_table, {:put, id, ref_id, position})
        :ok
      end)
      |> expect(:create_index, 6, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(create_table, {:put, id, ref_id, position})
        :ok
      end)

      :ok = Index.fix_index_tree(3, @dummy_type)

      assert GenServer.call(delete_table, :get) == %{
               1 => MapSet.new([{1, 98}]),
               2 => MapSet.new([{1, 99}])
             }

      assert GenServer.call(create_table, :get) == %{
               1 => MapSet.new([{1, 0}]),
               2 => MapSet.new([{2, 0}, {1, 1}]),
               3 => MapSet.new([{3, 0}, {2, 1}, {1, 2}])
             }

      verify!()
    end

    test "multiple item parents loop" do
      # Node, parent, grandparent.
      parent_data = %{
        1 => [3],
        2 => [1],
        3 => [2]
      }

      child_data = reverse_map(parent_data)

      index = %{
        1 => MapSet.new([{1, 98}]),
        2 => MapSet.new([{1, 99}]),
        3 => MapSet.new([])
      }

      {:ok, delete_table} = GenServer.start(MapSetStore, %{})
      {:ok, create_table} = GenServer.start(MapSetStore, %{})

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)
      |> stub(:get_index, fn id, _ -> map_fetch(index, id) end)
      |> expect(:delete_index, 4, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(delete_table, {:put, id, ref_id, position})
        :ok
      end)
      |> expect(:create_index, 18, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(create_table, {:put, id, ref_id, position})
        :ok
      end)

      :ok = Index.fix_index_tree(3, @dummy_type)

      assert GenServer.call(delete_table, :get) == %{
               1 => MapSet.new([{1, 98}]),
               2 => MapSet.new([{1, 99}])
             }

      assert GenServer.call(create_table, :get) == %{
               1 => MapSet.new([{1, 0}, {3, 1}, {2, 2}]),
               2 => MapSet.new([{2, 0}, {1, 1}, {3, 2}]),
               3 => MapSet.new([{3, 0}, {2, 1}, {1, 2}])
             }

      verify!()
    end

    test "multiple item children" do
      # Node, child, grandchild
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

      {:ok, delete_table} = GenServer.start(MapSetStore, %{})
      {:ok, create_table} = GenServer.start(MapSetStore, %{})

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)
      |> stub(:get_index, fn id, _ -> map_fetch(index, id) end)
      |> expect(:delete_index, 2, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(delete_table, {:put, id, ref_id, position})
        :ok
      end)
      |> expect(:create_index, 6, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(create_table, {:put, id, ref_id, position})
        :ok
      end)

      :ok = Index.fix_index_tree(3, @dummy_type)

      assert GenServer.call(delete_table, :get) == %{
               1 => MapSet.new([{1, 98}]),
               2 => MapSet.new([{1, 99}])
             }

      assert GenServer.call(create_table, :get) == %{
               1 => MapSet.new([{1, 0}]),
               2 => MapSet.new([{2, 0}, {1, 1}]),
               3 => MapSet.new([{3, 0}, {2, 1}, {1, 2}])
             }

      verify!()
    end

    test "multiple item children loop" do
      # Node, child, grandchild
      parent_data = %{
        1 => [3],
        2 => [1],
        3 => [2]
      }

      child_data = reverse_map(parent_data)

      index = %{
        1 => MapSet.new([{1, 98}]),
        2 => MapSet.new([{1, 99}]),
        3 => MapSet.new([])
      }

      {:ok, delete_table} = GenServer.start(MapSetStore, %{})
      {:ok, create_table} = GenServer.start(MapSetStore, %{})

      PenguinMemories.Database.Impl.Index.Mock
      |> stub(:get_parent_ids, fn id, _ -> map_fetch(parent_data, id) end)
      |> stub(:get_child_ids, fn id, _ -> map_fetch(child_data, id) end)
      |> stub(:get_index, fn id, _ -> map_fetch(index, id) end)
      |> expect(:delete_index, 4, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(delete_table, {:put, id, ref_id, position})
        :ok
      end)
      |> expect(:create_index, 18, fn id, {ref_id, position}, _ ->
        :ok = GenServer.call(create_table, {:put, id, ref_id, position})
        :ok
      end)

      :ok = Index.fix_index_tree(3, @dummy_type)

      assert GenServer.call(delete_table, :get) == %{
               1 => MapSet.new([{1, 98}]),
               2 => MapSet.new([{1, 99}])
             }

      assert GenServer.call(create_table, :get) == %{
               1 => MapSet.new([{1, 0}, {3, 1}, {2, 2}]),
               2 => MapSet.new([{2, 0}, {1, 1}, {3, 2}]),
               3 => MapSet.new([{3, 0}, {2, 1}, {1, 2}])
             }

      verify!()
    end
  end
end
