defmodule PenguinMemories.Database.Query do
  @moduledoc """
  Generic database functions
  """
  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi

  alias PenguinMemories.Database
  alias PenguinMemories.Database.Index
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.FileOrder
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo

  @type object_type :: Database.object_type()
  @type reference_type :: Database.reference_type()

  defmodule Icon do
    @moduledoc """
    All the attributes required to display an icon.
    """
    @type t :: %__MODULE__{
            id: integer,
            action: String.t() | nil,
            url: String.t(),
            name: String.t(),
            subtitle: String.t() | nil,
            width: integer,
            height: integer,
            type: module()
          }
    @enforce_keys [:id, :action, :url, :name, :subtitle, :width, :height, :type]
    defstruct [:id, :action, :url, :name, :subtitle, :width, :height, :type]
  end

  defmodule Video do
    @moduledoc """
    All the attributes required to display an icon
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

  defmodule Details do
    @moduledoc """
    Details from an object
    """
    @type t :: %__MODULE__{
            obj: struct(),
            icon: Icon.t() | nil,
            orig: Icon.t() | nil,
            videos: list(Video.t()),
            cursor: String.t(),
            type: Database.object_type(),
            parents: list(Icon.t()) | nil
          }
    @enforce_keys [:obj, :icon, :orig, :videos, :cursor, :type]
    defstruct [:obj, :icon, :orig, :videos, :cursor, :type, :parents]
  end

  defmodule Filter do
    @moduledoc """
    Details from an object
    """
    @type object_type :: Database.object_type()
    @type reference_type :: Database.reference_type()
    @type t :: %__MODULE__{
            ids: MapSet.t() | nil,
            query: String.t() | nil,
            reference: reference_type | nil
          }
    defstruct [:ids, :query, :reference]
  end

  @spec get_image_url() :: String.t()
  defp get_image_url do
    Application.get_env(:penguin_memories, :image_url)
  end

  @spec get_query_type(query :: Ecto.Query.t()) :: object_type()
  defp get_query_type(%Ecto.Query{} = query) do
    {_, type} = query.from.source
    type
  end

  @spec get_object_backend(object :: struct()) ::
          PenguinMemories.Database.Types.backend_type()
  defp get_object_backend(%{__struct__: type}) do
    Types.get_backend!(type)
  end

  @spec get_cursor_by_id(id :: integer(), type :: object_type()) :: String.t() | nil
  def get_cursor_by_id(id, type) do
    backend = Types.get_backend!(type)

    object =
      type
      |> query()
      |> filter_by_id(id)
      |> Repo.one()

    case object do
      nil -> nil
      object -> Paginator.cursor_for_record(object, backend.get_cursor_fields())
    end
  end

  @spec get_query_backend(query :: Ecto.Query.t()) ::
          PenguinMemories.Database.Types.backend_type()
  defp get_query_backend(%Ecto.Query{} = query) do
    query
    |> get_query_type()
    |> Types.get_backend!()
  end

  @spec get_single_name(type :: object_type()) :: String.t()
  def get_single_name(type) do
    backend = Types.get_backend!(type)
    backend.get_single_name()
  end

  @spec get_plural_name(type :: object_type()) :: String.t()
  def get_plural_name(type) do
    backend = Types.get_backend!(type)
    backend.get_plural_name()
  end

  @spec query(type :: object_type()) :: Ecto.Query.t()
  def query(type) do
    backend = Types.get_backend!(type)
    backend.query()
  end

  @spec filter_by_query(query :: Ecto.Query.t(), query_string :: String.t()) :: Ecto.Query.t()
  def filter_by_query(%Ecto.Query{} = query, query_string) do
    dynamic =
      dynamic([o], fragment("to_tsvector(?) @@ plainto_tsquery(?)", o.name, ^query_string))

    dynamic =
      case Integer.parse(query_string) do
        {int, ""} -> dynamic([o], ^dynamic or o.id == ^int)
        _ -> dynamic
      end

    from [object: o] in query, where: ^dynamic
  end

  @spec filter_by_id_map(query :: Ecto.Query.t(), ids :: MapSet.t()) :: Ecto.Query.t()
  def filter_by_id_map(%Ecto.Query{} = query, ids) do
    id_list = MapSet.to_list(ids)

    from [object: o] in query,
      where: o.id in ^id_list
  end

  @type filter_function :: (query :: Ecto.Query.t(), value :: any() -> Ecto.Query.t())

  @spec filter_if_set(query :: Ecto.Query.t(), value :: any(), filter_function()) ::
          Ecto.Query.t()
  def filter_if_set(%Ecto.Query{} = query, nil, _), do: query
  def filter_if_set(%Ecto.Query{} = query, value, function), do: function.(query, value)

  @spec filter_by_filter(
          query :: Ecto.Query.t(),
          filter :: Filter.t()
        ) :: Ecto.Query.t()
  def filter_by_filter(%Ecto.Query{} = query, %Filter{} = filter) do
    backend = get_query_backend(query)

    query
    |> filter_if_set(filter.ids, &filter_by_id_map/2)
    # |> filter_if_set(filter.photo_id, &backend.filter_by_photo_id/2)
    # |> filter_if_set(filter.parent_id, &backend.filter_by_parent_id/2)
    |> filter_if_set(filter.query, &filter_by_query/2)
    |> filter_if_set(filter.reference, &backend.filter_by_reference/2)
  end

  @spec filter_by_ascendants(query :: Ecto.Query.t(), id :: integer) :: Ecto.Query.t()
  def filter_by_ascendants(%Ecto.Query{} = query, id) do
    backend = get_query_backend(query)
    index_type = backend.get_index_type()

    from [object: o] in query,
      join: oa in ^index_type,
      on: o.id == oa.ascendant_id,
      as: :ascendants,
      where: oa.descendant_id == ^id
  end

  @spec filter_by_id(query :: Ecto.Query.t(), id :: integer) :: Ecto.Query.t()
  def filter_by_id(%Ecto.Query{} = query, id) when id != nil do
    from [object: o] in query,
      where: o.id == ^id
  end

  @spec get_icons(query :: Ecto.Query.t(), size_key :: String.t()) :: Ecto.Query.t()
  def get_icons(%Ecto.Query{} = query, size_key) do
    file_query =
      from f in File,
        where: f.size_key == ^size_key and f.mime_type == "image/jpeg"

    case get_query_type(query) do
      Photo ->
        from [object: o] in query,
          left_join: f in subquery(file_query),
          on: f.photo_id == o.id,
          as: :icon,
          select_merge: %{
            icon: %{
              dir: f.dir,
              filename: f.filename,
              height: f.height,
              width: f.width
            }
          }

      _ ->
        from [object: o] in query,
          left_join: p in Photo,
          on: p.id == o.cover_photo_id,
          as: :photo,
          left_join: f in subquery(file_query),
          on: f.photo_id == p.id,
          as: :icon,
          select_merge: %{
            icon: %{
              dir: f.dir,
              filename: f.filename,
              height: f.height,
              width: f.width
            }
          }
    end
  end

  @spec get_orig(query :: Ecto.Query.t()) :: Ecto.Query.t()
  def get_orig(%Ecto.Query{} = query) do
    case get_query_type(query) do
      Photo ->
        from [object: o] in query,
          left_join: f in File,
          on: f.photo_id == o.id and f.size_key == "orig",
          select_merge: %{
            orig: %{
              dir: f.dir,
              filename: f.filename,
              height: f.height,
              width: f.width
            }
          }

      _ ->
        from [object: o] in query,
          left_join: p in Photo,
          on: p.id == o.cover_photo_id,
          left_join: f in File,
          on: f.photo_id == p.id and f.size_key == "orig",
          select_merge: %{
            orig: %{
              dir: f.dir,
              filename: f.filename,
              height: f.height,
              width: f.width
            }
          }
    end
  end

  @spec get_icon_from_result(result :: map(), type :: object_type()) :: Icon.t()
  def get_icon_from_result(%{} = result, type) do
    backend = Types.get_backend!(type)

    url =
      if result.icon.dir do
        "#{get_image_url()}/#{result.icon.dir}/#{result.icon.filename}"
      end

    name = backend.get_title_from_result(result)
    subtitle = backend.get_subtitle_from_result(result)
    action = if type == Photo, do: result.o.action

    %Icon{
      id: result.id,
      action: action,
      url: url,
      name: name,
      subtitle: subtitle,
      height: result.icon.height,
      width: result.icon.width,
      type: type
    }
  end

  @spec get_orig_from_result(result :: map(), type :: object_type()) :: Icon.t()
  def get_orig_from_result(%{} = result, type) do
    backend = Types.get_backend!(type)

    url =
      if result.orig.dir do
        "#{get_image_url()}/#{result.orig.dir}/#{result.orig.filename}"
      end

    name = backend.get_title_from_result(result)
    subtitle = backend.get_subtitle_from_result(result)
    action = if type == Photo, do: result.o.action

    %Icon{
      id: result.id,
      action: action,
      url: url,
      name: name,
      subtitle: subtitle,
      height: result.orig.height,
      width: result.orig.width,
      type: type
    }
  end

  @spec get_videos_for_photo(photo_id :: integer(), size_key :: String.t()) ::
          list(Video.t())
  def get_videos_for_photo(photo_id, size_key) do
    file_query =
      from f in File,
        where: f.size_key == ^size_key and f.is_video == true and f.photo_id == ^photo_id,
        join: j in FileOrder,
        on: j.size_key == ^size_key and j.mime_type == f.mime_type,
        order_by: [asc: j.order],
        select_merge: %{
          dir: f.dir,
          filename: f.filename,
          height: f.height,
          width: f.width,
          mime_type: f.mime_type
        }

    entries = Repo.all(file_query)

    Enum.map(entries, fn result ->
      url =
        if result.dir do
          "#{get_image_url()}/#{result.dir}/#{result.filename}"
        end

      %Video{
        url: url,
        height: result.height,
        width: result.width,
        mime_type: result.mime_type,
        type: Photo
      }
    end)
  end

  @spec query_parents(id :: integer, type :: object_type()) :: list({Icon.t(), integer})
  def query_parents(_, Photo), do: []

  def query_parents(id, type) do
    query =
      query(type)
      |> filter_by_ascendants(id)
      |> get_icons("thumb")
      |> select_merge([ascendants: oa], %{position: oa.position})
      |> order_by([ascendants: oa], oa.position)

    icons =
      Enum.map(Repo.all(query), fn result ->
        {get_icon_from_result(result, type), result.position}
      end)

    icons
  end

  @spec query_icons_by_id_map(
          ids :: MapSet.t(),
          limit :: integer(),
          type :: object_type(),
          size_key :: String.t()
        ) :: list(Icon.t())
  def query_icons_by_id_map(ids, limit, type, size_key) do
    query =
      query(type)
      |> filter_by_id_map(ids)
      |> get_icons(size_key)
      |> limit(^limit)

    entries = Repo.all(query)

    Enum.map(entries, fn result ->
      get_icon_from_result(result, type)
    end)
  end

  @spec count_results(Filter.t(), type :: object_type()) :: integer()
  def count_results(%Filter{} = filter, type) do
    type
    |> query()
    |> filter_by_filter(filter)
    |> exclude(:preload)
    |> exclude(:select)
    |> exclude(:order_by)
    |> select([object: o], struct(o, [:id]))
    |> subquery
    |> select(count("*"))
    |> Repo.one!()
  end

  @spec query_icons(
          filter :: Filter.t(),
          limit :: integer,
          type :: object_type(),
          size_key :: String.t()
        ) :: list(Icon.t())
  def query_icons(%Filter{} = filter, limit, type, size_key) do
    query =
      query(type)
      |> filter_by_filter(filter)
      |> get_icons(size_key)
      |> limit(^limit)

    entries = Repo.all(query)

    Enum.map(entries, fn result ->
      get_icon_from_result(result, type)
    end)
  end

  @spec query_icon_by_id(id :: integer(), type :: object_type(), size_key :: String.t()) ::
          Icon.t() | nil
  def query_icon_by_id(id, type, size_key) when id != nil do
    query =
      query(type)
      |> filter_by_id(id)
      |> get_icons(size_key)

    case Repo.one(query) do
      nil -> nil
      result -> get_icon_from_result(result, type)
    end
  end

  @spec get_object_by_id(
          id :: integer,
          type :: object_type()
        ) :: Details.t() | nil
  def get_object_by_id(id, type) do
    query =
      query(type)
      |> filter_by_id(id)
      |> select_merge([object: o], %{o: o})

    case Repo.one(query) do
      nil ->
        nil

      result ->
        result.o
    end
  end

  @spec get_details(
          id :: integer,
          icon_size :: String.t(),
          video_size :: String.t(),
          type :: object_type()
        ) :: Details.t() | nil
  def get_details(id, icon_size, video_size, type) do
    backend = Types.get_backend!(type)

    query =
      query(type)
      |> filter_by_id(id)
      |> get_icons(icon_size)
      |> get_orig()
      |> backend.preload_details()
      |> select_merge([object: o], %{o: o})

    case Repo.one(query) do
      nil ->
        nil

      result ->
        parents =
          id
          |> query_parents(type)
          |> Enum.group_by(fn {_icon, position} -> position end)
          |> Enum.map(fn {position, list} ->
            {position, Enum.map(list, fn {icon, _} -> icon end)}
          end)
          |> Enum.sort_by(fn {position, _} -> -position end)

        details = backend.get_details_from_result(result, icon_size, video_size)
        %Details{details | parents: parents}
    end
  end

  @spec get_page_icons(
          filter :: Filter.t(),
          before_key :: String.t() | nil,
          after_key :: String.t() | nil,
          limit :: integer(),
          size_key :: String.t(),
          type :: object_type()
        ) :: {list(Icon.t()), String.t() | nil, String.t() | nil, integer}
  def get_page_icons(%Filter{} = filter, before_key, after_key, limit, size_key, type) do
    backend = Types.get_backend!(type)

    query =
      query(type)
      |> filter_by_filter(filter)
      |> get_icons(size_key)

    %{entries: entries, metadata: metadata} =
      Repo.paginate(
        query,
        before: before_key,
        after: after_key,
        cursor_fields: backend.get_cursor_fields(),
        limit: limit
      )

    icons =
      Enum.map(entries, fn result ->
        get_icon_from_result(result, type)
      end)

    {icons, metadata.before, metadata.after, metadata.total_count}
  end

  @spec get_prev_next_id(
          filter :: Filter.t(),
          before_key :: String.t() | nil,
          after_key :: String.t() | nil,
          size_key :: String.t(),
          type :: object_type()
        ) :: nil | Icon.t()
  def get_prev_next_id(%Filter{} = filter, before_key, after_key, size_key, type) do
    backend = Types.get_backend!(type)

    query =
      query(type)
      |> filter_by_filter(filter)
      |> get_icons(size_key)

    %{entries: entries, metadata: _} =
      Repo.paginate(
        query,
        before: before_key,
        after: after_key,
        cursor_fields: backend.get_cursor_fields(),
        limit: 1,
        include_total_count: false
      )

    case entries do
      [result] -> get_icon_from_result(result, type)
      [] -> nil
    end
  end

  @spec get_create_child_changeset(object :: struct(), attrs :: map(), assoc :: map()) ::
          {map(), Ecto.Changeset.t()}
  def get_create_child_changeset(object, attrs, assoc) do
    assoc =
      if Map.has_key?(object, :parent) do
        Map.put(assoc, :parent, object)
      else
        assoc
      end

    type = object.__struct__
    {assoc, get_edit_changeset(struct(type), attrs, assoc)}
  end

  @spec get_edit_changeset(object :: struct(), attrs :: map(), assoc :: map()) ::
          Ecto.Changeset.t()
  def get_edit_changeset(object, attrs, assoc) do
    backend = get_object_backend(object)
    backend.edit_changeset(object, attrs, assoc)
  end

  @spec get_changed_parents(changeset :: Ecto.Changeset.t()) :: list(integer())
  defp get_changed_parents(%Ecto.Changeset{} = changeset) do
    type = changeset.data.__struct__
    backend = Types.get_backend!(type)
    parent_fields = backend.get_parent_fields()

    Enum.map(parent_fields, fn field ->
      Ecto.Changeset.fetch_change(changeset, field)
    end)
    |> Enum.filter(fn
      {:ok, _value} -> true
      :error -> false
    end)
    |> Enum.map(fn
      {:ok, nil} -> nil
      {:ok, value} -> value.data.id
    end)
  end

  @spec fix_index(changeset :: Ecto.Changeset.t(), id :: integer(), cache :: Index.cache_type()) ::
          {:ok, Index.cache_type()}
  def fix_index(%Ecto.Changeset{} = changeset, id, cache) do
    # We can't use the id value from the changeset, because it will be nil for new objects.+
    type = changeset.data.__struct__
    parent_ids = get_changed_parents(changeset)

    case parent_ids do
      [] ->
        {:ok, cache}

      list_ids ->
        cache =
          Enum.reduce(list_ids, cache, fn
            nil, cache ->
              cache

            parent_id, cache ->
              {:ok, cache} = Index.fix_index_tree(parent_id, type, cache)
              cache
          end)

        Index.fix_index_tree(id, type, cache)
    end
  end

  @spec apply_changeset_to_multi(
          multi :: Multi.t(),
          changeset :: Changeset.t()
        ) :: Multi.t()
  defp apply_changeset_to_multi(%Multi{} = multi, %Changeset{} = changeset) do
    id = changeset.data.id

    multi
    |> Multi.insert_or_update({:update, id}, changeset)
    |> Multi.run({:index, id}, fn _, data ->
      obj = Map.fetch!(data, {:update, id})
      fix_index(changeset, obj.id, %{})
    end)
  end

  @spec apply_edit_changeset(changeset :: Changeset.t()) ::
          {:error, Changeset.t(), String.t()} | {:ok, map()}
  def apply_edit_changeset(%Changeset{} = changeset) do
    result =
      Multi.new()
      |> apply_changeset_to_multi(changeset)
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

  @spec get_index_api :: module()
  defp get_index_api do
    Application.get_env(:penguin_memories, :index_api)
  end

  @spec can_delete?(id :: integer, type :: object_type()) :: {:no, String.t()} | :yes
  def can_delete?(id, type) do
    index = get_index_api()
    child_ids = index.get_child_ids(id, type)

    cond do
      length(child_ids) > 0 ->
        {:no, "Cannot delete object with child"}

      true ->
        :yes
    end
  end

  @spec do_delete(object :: struct()) :: :ok | {:error, String.t()}
  defp do_delete(%Photo{} = photo) do
    result =
      get_edit_changeset(photo, %{action: "D"}, %{})
      |> Repo.update()

    case result do
      {:ok, _} -> :ok
      {:error, _} -> {:error, "Cannot delete photo"}
    end
  end

  defp do_delete(object) do
    type = object.__struct__
    backend = Types.get_backend!(type)
    index = backend.get_index_type()

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.delete_all(
        :index1,
        from(obj in index, where: obj.ascendant_id == ^object.id)
      )
      |> Ecto.Multi.delete_all(
        :index2,
        from(obj in index, where: obj.descendant_id == ^object.id)
      )
      |> Ecto.Multi.run(:object, fn _, _ -> Repo.delete(object) end)
      |> Repo.transaction()

    case result do
      {:ok, _} ->
        :ok

      {:error, :index1, _, _} ->
        {:error, "Cannot index 1"}

      {:error, :index2, _, _} ->
        {:error, "Cannot index 2"}

      {:error, :object, _, _} ->
        {:error, "Cannot delete object"}
    end
  end

  @spec delete(object :: struct()) :: :ok | {:error, String.t()}
  def delete(object) do
    case can_delete?(object.id, object.__struct__) do
      :yes -> do_delete(object)
      {:no, error} -> {:error, error}
    end
  end

  # @spec get_photo_params(id :: integer) :: map() | nil
  # def get_photo_params(id) do
  #   %{
  #     "album" => id
  #   }
  # end
end
