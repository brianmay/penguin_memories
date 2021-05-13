defmodule PenguinMemories.Objects do
  @moduledoc """
  Generic methods that apply to all object types
  """
  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi

  alias PenguinMemories.Media
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo

  defmodule Icon do
    @moduledoc """
    All the attributes required to display an icon.
    """
    @type t :: %__MODULE__{
            id: integer,
            action: String.t() | nil,
            url: String.t(),
            title: String.t(),
            subtitle: String.t(),
            width: integer,
            height: integer,
            type: module()
          }
    @enforce_keys [:id, :action, :url, :title, :subtitle, :width, :height, :type]
    defstruct [:id, :action, :url, :title, :subtitle, :width, :height, :type]
  end

  defmodule Video do
    @moduledoc """
    All the attributes required to display an icon.
    """
    @type t :: %__MODULE__{
            url: String.t(),
            width: integer,
            height: integer,
            mime_type: String.t(),
            type: module()
          }
    @enforce_keys [:url, :width, :height, :mime_type, :type]
    defstruct [:url, :width, :height, :mime_type, :type]
  end

  defmodule Field do
    @moduledoc """
    A field specification that can be displayed or edited.
    """
    @type t :: %__MODULE__{
            id: atom,
            title: String.t(),
            display: String.t() | nil,
            icons: list(Icon.t()) | nil,
            type:
              :string | :markdown | :album | :albums | :photo | :time | :utc_offset | :readonly
          }
    @enforce_keys [:id, :title, :display, :type]
    defstruct [:id, :title, :display, :type, :icons]
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
  @callback get_details(integer, String.t(), String.t()) ::
              {map(), Icon.t(), list(Video.t()), list(Field.t()), String.t()} | nil
  @callback get_page_icons(
              %{required(String.t()) => String.t()},
              String.t() | nil,
              String.t() | nil,
              integer()
            ) :: {list(Icon.t()), String.t() | nil, String.t() | nil, integer}
  @callback get_prev_next_id(
              %{required(String.t()) => String.t()},
              String.t() | nil,
              String.t() | nil
            ) :: nil | Icon.t()

  @callback search_icons(%{required(String.t()) => String.t()}, integer) :: list(Icon.t())

  @callback can_create?() :: boolean()
  @callback get_create_child_changeset(map(), map()) :: Ecto.Changeset.t()
  @callback get_edit_changeset(map(), map()) :: Ecto.Changeset.t()
  @callback get_update_changeset(MapSet.t(), map()) :: Ecto.Changeset.t()
  @callback has_parent_changed?(Changeset.t()) :: boolean
  @callback can_delete?(integer) :: {:no, String.t()} | :yes
  @callback delete(map()) :: :ok | {:error, String.t()}

  @callback get_photo_params(integer) :: map() | nil

  @spec get_for_type(String.t()) :: module()
  def get_for_type(type) do
    case type do
      "album" -> PenguinMemories.Objects.Album
      "photo" -> PenguinMemories.Objects.Photo
    end
  end

  @type seen_type :: MapSet.t()
  @type cache_type :: %{required(integer) => MapSet.t()}

  @spec generate_index(
          integer,
          integer,
          module(),
          seen_type,
          cache_type
        ) :: {seen_type, cache_type, MapSet.t()}
  def generate_index(id, position, type, seen, cache) when is_integer(id) do
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

        parents = type.get_parent_ids(id)

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

  @spec fix_index(integer, module, cache_type) :: cache_type
  def fix_index(id, type, cache) when is_integer(id) do
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
  def fix_index_parents(id, type, seen, cache) when is_integer(id) do
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
  def fix_index_children(id, type, seen, cache) when is_integer(id) do
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
  def fix_index_tree(id, type) when is_integer(id) do
    cache = %{}
    {_, cache} = fix_index_parents(id, type, MapSet.new(), cache)

    # Note we have to descend all children even if we have seen the parent
    # before, This may lead to duplication of nodes processed in weird
    # situations. However we try to avoid processing id twice, so make testing
    # easier.
    seen = MapSet.new()
    children = type.get_child_ids(id)

    {_, _} =
      Enum.reduce(children, {seen, cache}, fn
        child, {seen, cache} -> fix_index_children(child, type, seen, cache)
      end)

    :ok
  end

  @spec apply_changeset_to_multi(Multi.t(), Changeset.t(), module()) :: Multi.t()
  defp apply_changeset_to_multi(multi, changeset, type) do
    id = changeset.data.id

    multi
    |> Multi.insert_or_update({:update, id}, changeset)
    |> Multi.run({:index, id}, fn _, data ->
      case type.has_parent_changed?(changeset) do
        false ->
          nil

        true ->
          obj = Map.fetch!(data, {:update, id})
          :ok = fix_index_tree(obj.id, type)
      end

      {:ok, nil}
    end)
  end

  @spec apply_edit_changeset(Changeset.t(), module()) ::
          {:error, Changeset.t(), String.t()} | {:ok, map()}
  def apply_edit_changeset(changeset, type) do
    result =
      Multi.new()
      |> apply_changeset_to_multi(changeset, type)
      |> Repo.transaction()

    case result do
      {:ok, data} ->
        obj = Map.fetch!(data, {:update, changeset.data.id})
        {:ok, obj}

      {:error, {:update, _id}, changeset, _} ->
        {:error, changeset, "The update failed"}

      {:error, {:index, _id}, error, _} ->
        {:error, changeset, "Error #{inspect(error)} while indexing"}
    end
  end

  @spec apply_update_changeset(list(integer), Changeset.t(), MapSet.t(), module()) ::
          {:error, String.t()} | :ok
  def apply_update_changeset(id_list, changeset, fields, type) do
    case Changeset.apply_action(changeset, :update) do
      {:error, error} ->
        {:error, "The changeset is invalid: #{inspect(error)}"}

      {:ok, obj} ->
        changes =
          Enum.reduce(fields, %{}, fn field_id, acc ->
            Map.put(acc, field_id, Map.fetch!(obj, field_id))
          end)

        apply_update_changes(id_list, changes, type)
    end
  end

  @spec subst_string_values(String.t(), keyword()) :: String.t()
  defp subst_string_values(msg, opts) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  @spec errors_to_strings(Changeset.t()) :: %{atom() => list(String.t())}
  defp errors_to_strings(changeset) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      subst_string_values(msg, opts)
    end)
  end

  @spec apply_update_changes(list(integer), map(), module()) :: {:error, String.t()} | :ok
  def apply_update_changes(id_list, changes, type) do
    multi = Multi.new()

    multi =
      Enum.reduce(id_list, multi, fn id, multi ->
        case type.get_details(id) do
          nil ->
            Multi.error(multi, {:error, id}, "Cannot find object #{id}")

          {obj, _, _} ->
            obj_changeset = type.get_edit_changeset(obj, changes)
            apply_changeset_to_multi(multi, obj_changeset, type)
        end
      end)

    case Repo.transaction(multi) do
      {:ok, _data} ->
        :ok

      {:error, {:update, id}, changeset, _data} ->
        errors =
          errors_to_strings(changeset)
          |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
          |> Enum.join(", ")

        {:error, "The update of id #{id} failed: #{errors}"}

      {:error, {:index, id}, error, _data} ->
        {:error, "Error #{inspect(error)} while indexing id #{id}"}

      {:error, {:error, id}, error, _data} ->
        {:error, "Error looking for #{id}: #{error}"}
    end
  end

  @spec get_title(String.t() | nil, integer() | nil) :: String.t() | nil
  def get_title(nil, nil), do: nil
  def get_title(name, id), do: "#{name} (#{id})"

  @spec display_datetime_offset(DateTime.t() | nil, integer | nil) :: String.t() | nil
  def display_datetime_offset(nil, _), do: nil

  def display_datetime_offset(datetime, nil) do
    display_datetime_offset(datetime, 0)
  end

  def display_datetime_offset(datetime, offset) do
    offset = offset * 60
    datetime = DateTime.add(datetime, offset)
    datetime = %{datetime | utc_offset: offset}
    DateTime.to_string(datetime)
  end

  @spec display_datetime(DateTime.t() | nil) :: String.t() | nil
  def display_datetime(nil), do: nil

  def display_datetime(datetime) do
    datetime
    |> DateTime.shift_zone!("Australia/Melbourne")
    |> DateTime.to_string()
  end

  @spec get_photo_dir_conflicts(String.t(), String.t()) :: list(Photo.t())
  def get_photo_dir_conflicts(new_dir, new_name) do
    photo_query =
      from p in Photo,
        where: p.dir == ^new_dir and p.name == ^new_name

    Repo.all(photo_query)
  end

  @spec get_file_dir_conflicts(String.t(), String.t()) :: list(Photo.t())
  def get_file_dir_conflicts(new_dir, new_name) do
    file_query =
      from f in File,
        where: f.dir == ^new_dir and f.name == ^new_name

    Repo.all(file_query)
  end

  @spec get_file_hash_conflicts(Media.t(), String.t()) :: list(File.t())
  def get_file_hash_conflicts(media, size_key) do
    num_bytes = Media.get_num_bytes(media)
    sha256_hash = Media.get_sha256_hash(media)

    file_query =
      from f in File,
        where:
          f.size_key == ^size_key and f.num_bytes == ^num_bytes and
            f.sha256_hash == ^sha256_hash

    Repo.all(file_query)
  end
end
