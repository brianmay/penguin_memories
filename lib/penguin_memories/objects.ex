defmodule PenguinMemories.Objects do
  @moduledoc """
  Generic methods that apply to all object types
  """
  alias Ecto.Changeset
  alias Ecto.Multi

  alias PenguinMemories.Repo

  defmodule Icon do
    @moduledoc """
    All the attributes required to display an icon.
    """
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
    @moduledoc """
    A field specification that can be displayed or edited.
    """
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
  @callback get_update_fields() :: list(Field.t())
  @callback get_parents(integer) :: list({Icon.t(), integer})
  @callback get_details(integer) :: {map(), Icon.t(), list(Field.t())} | nil
  @callback get_page_icons(%{required(String.t()) => String.t()}, MapSet.t()|nil, String.t()|nil, String.t()|nil) :: {list(Icon.t), String.t()|nil, String.t()|nil, integer}
  @callback get_icons(MapSet.t()|nil, integer()) :: list(Icon.t())

  @callback get_create_child_changeset(map(), map()) :: Ecto.Changeset.t()
  @callback get_edit_changeset(map(), map()) :: Ecto.Changeset.t()
  @callback get_update_changeset(map()) :: Ecto.Changeset.t()
  @callback has_parent_changed?(Changeset.t()) :: boolean
  @callback can_delete?(integer) :: {:no, String.t()} | :yes
  @callback delete(map()) :: :ok | {:error, String.t()}


  @spec get_for_type(String.t()) :: module()
  def get_for_type(type) do
    case type do
      "album" -> PenguinMemories.Objects.Album
    end
  end

  @type seen_type :: MapSet.t()
  @type cache_type :: %{required(integer) => MapSet.t()}

  @spec generate_index(
    integer, integer, module(), seen_type,
    cache_type
  ) :: {seen_type, cache_type, MapSet.t()}
  def generate_index(id, position, type, seen, cache) do
    cond  do
      Map.has_key?(cache, id) ->
        cache_item = Map.fetch!(cache, id)

        index = MapSet.new()
        index = Enum.reduce(cache_item, index, fn
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

        parents = type.get_parent_ids(id)
        {seen, cache, index} = Enum.reduce(parents, {seen, cache, index}, fn
          parent_id, {seen, cache, index} ->
            {seen, cache, new_index} = generate_index(parent_id, position + 1, type, seen, cache)
            {seen, cache, MapSet.union(index, new_index)}
        end)

        cache_item = Enum.reduce(index, MapSet.new(), fn
          {a, b}, cache_item -> MapSet.put(cache_item, {a, b - position})
        end)
        cache = Map.put(cache, id, cache_item)

        {seen, cache, index}
    end
  end

  @spec fix_index(integer, module, cache_type) :: cache_type
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

  @spec fix_index_parents(integer, module, seen_type, cache_type) :: {seen_type, cache_type}
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

  @spec fix_index_children(integer, module, seen_type, cache_type) :: {seen_type, cache_type}
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

  @spec fix_index_tree(integer, module()) :: :ok
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

    :ok
  end

  @spec apply_edit_changeset(Changeset.t(), module()) :: {:error, Changeset.t(), String.t()} | {:ok, map()}
  def apply_edit_changeset(changeset, type) do
    result = Multi.new()
    |> Multi.insert_or_update(:update, changeset)
    |> Multi.run(:index, fn _, obj ->
      case type.has_parent_changed?(changeset) do
        false -> nil
        true -> :ok = fix_index_tree(obj.update.id, type)
      end
      {:ok, nil}
    end)
    |> Repo.transaction()

    case result do
      {:ok, data} ->
        {:ok, data.update}
      {:error, :update, changeset, _} ->
        {:error, changeset, "The update failed"}
      {:error, :index, error, _} ->
        {:error, changeset, "Error #{inspect error} while indexing"}
    end
  end

end
