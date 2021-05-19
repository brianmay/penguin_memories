defmodule PenguinMemories.Database.Index do
  @moduledoc """
  Indexing parent/child relationships
  """
  alias PenguinMemories.Database
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

    Enum.each(
      MapSet.difference(old_index, new_index),
      fn index -> :ok = api.delete_index(id, index, type) end
    )

    Enum.each(
      MapSet.difference(new_index, old_index),
      fn index -> :ok = api.create_index(id, index, type) end
    )

    cache
  end

  @spec fix_index_parents(integer, object_type, seen_type, cache_type) :: {seen_type, cache_type}
  def fix_index_parents(id, type, seen, cache) when is_integer(id) do
    api = get_index_api()

    cond do
      MapSet.member?(seen, id) ->
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

  @spec fix_index_tree(integer, object_type) :: :ok
  def fix_index_tree(id, type) when is_integer(id) do
    api = get_index_api()

    cache = %{}
    {_, cache} = fix_index_parents(id, type, MapSet.new(), cache)

    # Note we have to descend all children even if we have seen the parent
    # before, This may lead to duplication of nodes processed in weird
    # situations. However we try to avoid processing id twice, so make testing
    # easier.
    seen = MapSet.new()
    children = api.get_child_ids(id, type)

    {_, _} =
      Enum.reduce(children, {seen, cache}, fn
        child, {seen, cache} -> fix_index_children(child, type, seen, cache)
      end)

    :ok
  end
end
