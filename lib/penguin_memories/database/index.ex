defmodule PenguinMemories.Database.Index do
  @moduledoc """
  Indexing parent/child relationships
  """
  import Ecto.Query

  alias PenguinMemories.Database
  alias PenguinMemories.Photos
  alias PenguinMemories.Repo

  @type object_type :: Database.object_type()
  # @type seen_type :: MapSet.t()
  # @type cache_type :: %{required(integer) => MapSet.t()}

  @type index_type :: %{integer() => integer()}
  @type index_api_type :: module()

  @spec get_index_api :: index_api_type
  def get_index_api do
    Application.get_env(:penguin_memories, :index_api)
  end

  @type relations :: %{integer => integer}

  @spec walk_tree(
          id :: integer,
          parents :: relations(),
          children :: relations(),
          type :: object_type(),
          api :: index_api_type()
        ) :: {:ok, relations(), relations()}
  def walk_tree(id, parents, children, type, api) do
    parent_list =
      if Map.has_key?(parents, id) do
        []
      else
        api.get_parent_ids(id, type)
      end

    child_list =
      if Map.has_key?(children, id) do
        []
      else
        api.get_child_ids(id, type)
      end

    parents = Map.put_new(parents, id, [])
    children = Map.put_new(children, id, [])

    parents =
      Enum.reduce(parent_list, parents, fn parent_id, parents ->
        Map.update!(parents, id, fn the_list ->
          [parent_id | the_list]
        end)
      end)

    children =
      Enum.reduce(child_list, children, fn child_id, children ->
        Map.update!(children, id, fn the_list ->
          [child_id | the_list]
        end)
      end)

    {parents, children} =
      Enum.reduce(parent_list, {parents, children}, fn parent_id, {parents, children} ->
        {:ok, parents, children} = walk_tree(parent_id, parents, children, type, api)
        {parents, children}
      end)

    {parents, children} =
      Enum.reduce(child_list, {parents, children}, fn child_id, {parents, children} ->
        {:ok, parents, children} = walk_tree(child_id, parents, children, type, api)
        {parents, children}
      end)

    {:ok, parents, children}
  end

  @spec generate_index(
          id :: integer(),
          position :: integer(),
          parents :: relations(),
          children :: relations(),
          index :: index_type(),
          opts :: keyword()
        ) :: {:ok, index_type()}
  def generate_index(id, position, parents, children, index, opts \\ []) do
    if Map.has_key?(index, id) do
      {:ok, index}
    else
      index = Map.put(index, id, position)

      # Note we don't care about the children of a parent.
      index =
        if opts[:do_parents] do
          parent_list = Map.fetch!(parents, id)

          Enum.reduce(parent_list, index, fn parent_id, index ->
            {:ok, index} =
              generate_index(parent_id, position + 1, parents, children, index, do_parents: true)

            index
          end)
        else
          index
        end

      # Note we don't care about the parents of a child.
      index =
        if opts[:do_children] do
          child_list = Map.fetch!(children, id)

          Enum.reduce(child_list, index, fn child_id, index ->
            {:ok, index} =
              generate_index(child_id, position - 1, parents, children, index, do_children: true)

            index
          end)
        else
          index
        end

      {:ok, index}
    end
  end

  @spec update_index(
          id :: integer,
          index :: index_type,
          type :: object_type,
          api :: index_api_type()
        ) :: :ok
  def update_index(id, index, type, api) do
    old_index = api.get_index(id, type)

    new_index =
      Enum.reduce(index, MapSet.new(), fn
        {_id, _position} = index, mapset -> MapSet.put(mapset, index)
      end)

    # IO.puts("")
    # IO.puts("xxxxxxx #{id}")
    # IO.inspect(old_index)
    # IO.inspect(index)
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

    :ok
  end

  @spec fix_index_tree_internal(
          id :: integer,
          parents :: relations(),
          children :: relations(),
          type :: object_type,
          api :: index_api_type(),
          seen :: MapSet.t()
        ) :: {:ok, relations(), relations(), MapSet.t()}
  defp fix_index_tree_internal(id, parents, children, type, api, seen) do
    if MapSet.member?(seen, id) do
      {:ok, parents, children, seen}
    else
      seen = MapSet.put(seen, id)

      {:ok, parents, children} = walk_tree(id, parents, children, type, api)

      {:ok, index} =
        generate_index(id, 0, parents, children, %{}, do_parents: true, do_children: true)

      :ok = update_index(id, index, type, api)

      parent_list = Map.get(parents, id)
      children_list = Map.get(children, id)

      {parents, children, seen} =
        Enum.reduce(parent_list, {parents, children, seen}, fn id, {parents, children, seen} ->
          {:ok, parents, children, seen} =
            fix_index_tree_internal(id, parents, children, type, api, seen)

          {parents, children, seen}
        end)

      {parents, children, seen} =
        Enum.reduce(children_list, {parents, children, seen}, fn id, {parents, children, seen} ->
          {:ok, parents, children, seen} =
            fix_index_tree_internal(id, parents, children, type, api, seen)

          {parents, children, seen}
        end)

      {:ok, parents, children, seen}
    end
  end

  @spec fix_index_tree(
          id :: integer,
          parents :: relations(),
          children :: relations(),
          type :: object_type,
          api :: index_api_type()
        ) :: {:ok, relations(), relations()}
  def fix_index_tree(id, parents, children, type, api) do
    seen = MapSet.new()
    {:ok, parents, children, _} = fix_index_tree_internal(id, parents, children, type, api, seen)
    {:ok, parents, children}
  end

  @spec internal_process_pending(
          type :: object_type,
          start_id :: integer,
          parents :: relations(),
          children :: relations()
        ) :: :ok
  defp internal_process_pending(type, start_id, parents, children) do
    obj =
      Repo.one(
        from(o in type,
          where: o.reindex and o.id >= ^start_id,
          limit: 1,
          order_by: :id
        )
      )

    api = get_index_api()

    case obj do
      nil ->
        :ok

      obj ->
        {:ok, {parents, children}} =
          Repo.transaction(fn ->
            {:ok, parents, children} = fix_index_tree(obj.id, parents, children, type, api)
            {parents, children}
          end)

        internal_process_pending(type, obj.id + 1, parents, children)
    end
  end

  @spec process_pending(object_type) :: :ok
  def process_pending(type) do
    :ok = internal_process_pending(type, 0, %{}, %{})
  end

  @spec process_all :: :ok
  def process_all do
    :ok = process_pending(Photos.Album)
    :ok = process_pending(Photos.Category)
    :ok = process_pending(Photos.Person)
    :ok = process_pending(Photos.Place)
  end
end
