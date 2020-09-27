defmodule PenguinMemories.Objects do
  alias Ecto.Changeset

  defmodule Icon do
    @type t :: %__MODULE__{
      id: integer,
      action: String.t(),
      url: String.t(),
      title: String.t(),
      subtitle: String.t(),
      width: integer,
      height: integer,
    }
    @enforce_keys [:id, :action, :url, :title, :subtitle, :width, :height]
    defstruct [:id, :action, :url, :title, :subtitle, :width, :height]
  end

  defmodule Field do
    @type t :: %__MODULE__{
      id: atom,
      title: String.t(),
      display: String.t() | nil,
      type: :string|:markdown|:album|:photo|:time|:utc_offset
    }
    @enforce_keys [:id, :title, :display, :type]
    defstruct [:id, :title, :display, :type]
  end

  @callback get_parent_ids(integer) :: list(integer())
  @callback get_child_ids(integer) :: list(integer())
  @callback get_index(integer) :: list(MapSet.t())
  @callback create_index(integer, {integer, integer}) :: :ok
  @callback delete_index(integer, {integer, integer}) :: :ok

  @callback get_type_name() :: String.t()
  @callback get_plural_title() :: String.t()
  @callback get_bulk_update_fields() :: list(Field.t())
  @callback get_parents(integer) :: list(Icon.t())
  @callback get_details(integer) :: {map(), Icon.t(), list(Field.t())} | nil
  @callback get_page_icons(%{required(String.t()) => String.t()}, MapSet.t()|nil, String.t()|nil, String.t()|nil) :: {list(Icon.t), String.t()|nil, String.t()|nil, integer}
  @callback get_icons(MapSet.t()|nil, integer()) :: list(Icon.t())

  @callback create_child_changeset(map(), map()) :: Ecto.Changeset.t()
  @callback update_changeset(map(), map()) :: Ecto.Changeset.t()
  @callback update(Changeset.t()) :: {:error, Changeset.t(), String.t()} | {:ok, map()}
  @callback can_delete?(integer) :: {:no, String.t()} | :yes
  @callback delete(map()) :: :ok | {:error, String.t()}


  def get_for_type(type) do
    case type do
      "album" -> PenguinMemories.Objects.Album
    end
  end

  @spec generate_index(
    integer, integer, module(), MapSet.t(),
    %{required(integer) => String.t()}
  ) :: {MapSet.t(), %{required(integer) => String.t()}, MapSet.t()}
  def generate_index(id, position, type, seen, cache) do
    cond  do
      Map.has_key?(cache, id) ->
        cache_item = Map.fetch!(cache, id)

        index = MapSet.new()
        index = Enum.reduce(cache_item, index, fn
          {a, b}, index -> MapSet.put(index, {a, b+position})
        end)

        {seen, cache, index}

      MapSet.member?(seen, id) ->
        index = MapSet.new()
        {seen, cache, index}

      true ->
        seen = MapSet.put(seen, id)

        index = MapSet.new()
        index = MapSet.put(index, {id, position})

        parents = type.get_parent_ids(id)
        {seen, cache, index} = Enum.reduce(parents, {seen, cache, index}, fn
          parent_id, {seen, cache, index} ->
            {seen, cache, new_index} = generate_index(parent_id, position + 1, type, seen, cache)
            {seen, cache, MapSet.union(index, new_index)}
        end)

        cache_item = Enum.reduce(index, MapSet.new(), fn
          {a, b}, cache_item -> MapSet.put(cache_item, {a, b-position})
        end)
        cache = Map.put(cache, id, cache_item)

        {seen, cache, index}
    end
  end

  def fix_index(id, type, cache) do
    {_, cache, new_index} = generate_index(id, 0, type, MapSet.new(), cache)
    old_index = type.get_index(id)

    Enum.each(
      MapSet.difference(old_index, new_index),
      fn index -> :ok = type.delete_index(id, index) end
    )

    Enum.each(
      MapSet.difference(new_index, old_index),
      fn index -> :ok = type.create_index(id, index) end
    )

    cache
  end

  def fix_index_parents(id, type, seen, cache) do
    cond do
      MapSet.member?(seen, id) ->
        {seen, cache}
      true ->
        fix_index(id, type, cache)
        parents = type.get_parent_ids(id)
        seen = MapSet.put(seen, id)
        Enum.reduce(parents, {seen, cache}, fn
          parent, {seen, cache} -> fix_index_parents(parent, type, seen, cache)
        end)
    end
  end

  def fix_index_children(id, type, seen, cache) do
    cond do
      MapSet.member?(seen, id) ->
        {seen, cache}
      true ->
        fix_index(id, type, cache)
        children = type.get_child_ids(id)
        seen = MapSet.put(seen, id)
        Enum.reduce(children, {seen, cache}, fn
          child, {seen, cache} -> fix_index_children(child, type, seen, cache)
        end)
    end
  end

  def fix_index_tree(id, type) do
    cache = %{}
    {_, cache} = fix_index_parents(id, type, MapSet.new(), cache)

    # Note we have to descend all children even if we have seen the parent
    # before, This may lead to duplication of nodes processed in weird
    # situations. However we try to avoid processing id twice, so make testing
    # easier.
    seen = MapSet.new()
    children = type.get_child_ids(id)
    Enum.reduce(children, {seen, cache}, fn
      child, {seen, cache} -> fix_index_children(child, type, seen, cache)
    end)

    {:ok, nil}
  end

end
