defmodule PenguinMemories.Database.Index do
  @moduledoc """
  Indexing parent/child relationships
  """
  import Ecto.Query

  alias PenguinMemories.Database
  alias PenguinMemories.Photos
  alias PenguinMemories.Repo

  @type object_type :: Database.object_type()
  @type seen_type :: MapSet.t()
  @type cache_type :: %{required(integer) => MapSet.t()}

  @spec get_index_api :: module()
  defp get_index_api do
    Application.get_env(:penguin_memories, :index_api)
  end

  @spec generate_index(
          integer,
          integer,
          object_type,
          seen_type,
          cache_type
        ) :: {seen_type, cache_type, MapSet.t()}
  def generate_index(id, position, type, seen, cache) when is_integer(id) do
    api = get_index_api()

    cond do
      Map.has_key?(cache, id) ->
        cache_item = Map.fetch!(cache, id)

        index = MapSet.new()

        index =
          Enum.reduce(cache_item, index, fn
            {a, b}, index -> MapSet.put(index, {a, b + position})
          end)

        {seen, cache, index}

      MapSet.member?(seen, id) ->
        # Seen is to prevent infinite loops if
        # we have a circular structure.
        index = MapSet.new()
        {seen, cache, index}

      true ->
        seen = MapSet.put(seen, id)

        index = MapSet.new()
        index = MapSet.put(index, {id, position})

        parents = api.get_parent_ids(id, type)

        {seen, cache, index} =
          Enum.reduce(parents, {seen, cache, index}, fn
            parent_id, {seen, cache, index} ->
              {seen, cache, new_index} =
                generate_index(parent_id, position + 1, type, seen, cache)

              {seen, cache, MapSet.union(index, new_index)}
          end)

        cache_item =
          Enum.reduce(index, MapSet.new(), fn
            {a, b}, cache_item -> MapSet.put(cache_item, {a, b - position})
          end)

        cache = Map.put(cache, id, cache_item)

        {seen, cache, index}
    end
  end

  @spec fix_index(integer, object_type, cache_type) :: cache_type
  def fix_index(id, type, cache) when is_integer(id) do
    api = get_index_api()

    {_, cache, new_index} = generate_index(id, 0, type, MapSet.new(), cache)
    old_index = api.get_index(id, type)

    # IO.puts("")
    # IO.puts("xxxxxxx #{id}")

    # IO.inspect(old_index)
    # IO.inspect(new_index)

    new_index_ids =
      Enum.reduce(new_index, MapSet.new(), fn
        {ref_id, _}, mapset -> MapSet.put(mapset, ref_id)
      end)

    old_index_ids =
      Enum.reduce(old_index, MapSet.new(), fn
        {ref_id, _}, mapset -> MapSet.put(mapset, ref_id)
      end)

    Enum.each(
      MapSet.difference(old_index_ids, new_index_ids),
      fn ref_id ->
        # IO.inspect("delete #{id} #{inspect(ref_id)}")
        :ok = api.delete_index(id, ref_id, type)
      end
    )

    Enum.each(
      MapSet.difference(new_index, old_index),
      fn {ref_id, _} = index ->
        if MapSet.member?(old_index_ids, ref_id) do
          # IO.inspect("update #{id} #{inspect(index)}")
          :ok = api.update_index(id, index, type)
        else
          # IO.inspect("create #{id} #{inspect(index)}")
          :ok = api.create_index(id, index, type)
        end
      end
    )

    api.set_done(id, type)
    cache
  end

  @spec fix_index_parents(integer, object_type, seen_type, cache_type) :: {seen_type, cache_type}
  def fix_index_parents(id, type, seen, cache) when is_integer(id) do
    api = get_index_api()

    cond do
      MapSet.member?(seen, id) ->
        # Seen is independant of seen in generate_index
        # but also to prevent circular loops.
        {seen, cache}

      true ->
        fix_index(id, type, cache)
        parents = api.get_parent_ids(id, type)
        seen = MapSet.put(seen, id)

        Enum.reduce(parents, {seen, cache}, fn
          parent, {seen, cache} -> fix_index_parents(parent, type, seen, cache)
        end)
    end
  end

  @spec fix_index_children(integer, object_type, seen_type, cache_type) :: {seen_type, cache_type}
  def fix_index_children(id, type, seen, cache) when is_integer(id) do
    api = get_index_api()

    cond do
      MapSet.member?(seen, id) ->
        # Seen is independant of seen in generate_index
        # but also to prevent circular loops.
        {seen, cache}

      true ->
        fix_index(id, type, cache)
        children = api.get_child_ids(id, type)
        seen = MapSet.put(seen, id)

        Enum.reduce(children, {seen, cache}, fn
          child, {seen, cache} -> fix_index_children(child, type, seen, cache)
        end)
    end
  end

  @spec fix_index_tree(integer, object_type, cache_type) :: {:ok, cache_type}
  def fix_index_tree(id, type, cache \\ %{}) when is_integer(id) do
    api = get_index_api()
    {_, cache} = fix_index_parents(id, type, MapSet.new(), cache)

    # Note we have to descend all children even if we have seen the parent
    # before, This may lead to duplication of nodes processed in weird
    # situations. However we try to avoid processing id twice, so make testing
    # easier.
    seen = MapSet.new()
    children = api.get_child_ids(id, type)

    {_, cache} =
      Enum.reduce(children, {seen, cache}, fn
        child, {seen, cache} -> fix_index_children(child, type, seen, cache)
      end)

    {:ok, cache}
  end

  @spec internal_process_pending(object_type, integer, cache_type) :: :ok
  defp internal_process_pending(type, start_id, cache) do
    obj =
      Repo.one(
        from o in type,
          where: o.reindex and o.id >= ^start_id,
          limit: 1,
          order_by: :id
      )

    case obj do
      nil ->
        :ok

      obj ->
        {:ok, cache} =
          Repo.transaction(fn ->
            fix_index(obj.id, type, cache)
          end)

        internal_process_pending(type, obj.id + 1, cache)
    end
  end

  @spec process_pending(object_type) :: :ok
  def process_pending(type) do
    cache = %{}
    internal_process_pending(type, 0, cache)
  end

  @spec process_all :: :ok
  def process_all do
    :ok = process_pending(Photos.Album)
    :ok = process_pending(Photos.Category)
    :ok = process_pending(Photos.Person)
    :ok = process_pending(Photos.Place)
  end
end
