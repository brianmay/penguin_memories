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

  defmodule Icon do
    @moduledoc """
    All the attributes required to display an icon.
    """
    @type t :: %__MODULE__{
            id: integer,
            action: String.t() | nil,
            url: String.t(),
            title: String.t(),
            subtitle: String.t() | nil,
            width: integer,
            height: integer,
            type: module()
          }
    @enforce_keys [:id, :action, :url, :title, :subtitle, :width, :height, :type]
    defstruct [:id, :action, :url, :title, :subtitle, :width, :height, :type]
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
            videos: list(Video.t()),
            cursor: String.t(),
            type: Database.object_type()
          }
    @enforce_keys [:obj, :icon, :videos, :cursor, :type]
    defstruct [:obj, :icon, :videos, :cursor, :type]
  end

  defmodule Filter do
    @moduledoc """
    Details from an object
    """
    @type object_type :: Database.object_type()
    @type t :: %__MODULE__{
            ids: MapSet.t() | nil,
            query: String.t() | nil,
            reference: {object_type(), integer()} | nil
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
    filtered_search = ["%", String.replace(query_string, "%", ""), "%"]
    filtered_search = Enum.join(filtered_search)
    dynamic = dynamic([o], ilike(o.title, ^filtered_search))

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
    |> filter_if_set(filter.ids, &backend.filter_by_id_map/2)
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
        where: f.size_key == ^size_key and f.is_video == false,
        join: j in FileOrder,
        on: j.size_key == ^size_key and j.mime_type == f.mime_type,
        distinct: f.photo_id,
        order_by: [asc: j.order]

    case get_query_type(query) do
      Photo ->
        from [object: o] in query,
          left_join: f in subquery(file_query),
          on: f.photo_id == o.id,
          as: :icon,
          select_merge: %{
            icon: %{
              title: o.title,
              utc_offset: o.utc_offset,
              dir: f.dir,
              name: f.name,
              height: f.height,
              width: f.width,
              action: o.action
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
              name: f.name,
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
        "#{get_image_url()}/#{result.icon.dir}/#{result.icon.name}"
      end

    title = backend.get_title_from_result(result)
    subtitle = backend.get_subtitle_from_result(result)
    action = if type == Photo, do: result.o.action

    %Icon{
      id: result.id,
      action: action,
      url: url,
      title: title,
      subtitle: subtitle,
      height: result.icon.height,
      width: result.icon.width,
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
          name: f.name,
          height: f.height,
          width: f.width,
          mime_type: f.mime_type
        }

    entries = Repo.all(file_query)

    Enum.map(entries, fn result ->
      url =
        if result.dir do
          "#{get_image_url()}/#{result.dir}/#{result.name}"
        end

      %Video{
        url: url,
        height: result.height,
        width: result.width,
        mime_type: result.mime_type,
        type: __MODULE__
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
      |> backend.preload_details()
      |> select_merge([object: o], %{o: o})

    case Repo.one(query) do
      nil ->
        nil

      result ->
        backend.get_details_from_result(result, icon_size, video_size)
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
          Ecto.Changeset.t()
  def get_create_child_changeset(object, attrs, assoc) do
    assoc =
      if Map.has_key?(object, :parent) do
        Map.put(assoc, :parent, object)
      else
        assoc
      end

    get_edit_changeset(object, attrs, assoc)
  end

  @spec get_edit_changeset(object :: struct(), attrs :: map(), assoc :: map()) ::
          Ecto.Changeset.t()
  def get_edit_changeset(object, attrs, assoc) do
    type = object.__struct__
    type.edit_changeset(object, attrs, assoc)
  end

  # @spec get_update_changeset(enabled :: MapSet.t(), attrs :: map(), type :: object_type()) ::
  #         Ecto.Changeset.t()
  # def get_update_changeset(enabled, attrs, type) do
  #   type.update_changeset(enabled, attrs)
  # end

  @spec has_parent_changed?(changeset :: Ecto.Changeset.t()) :: boolean
  def has_parent_changed?(%Ecto.Changeset{data: object} = changeset) do
    type = object.__struct__
    backend = Types.get_backend!(type)
    parent_fields = backend.get_parent_fields()

    Enum.any?(parent_fields, fn field ->
      case Ecto.Changeset.fetch_change(changeset, field) do
        :error -> false
        {:ok, _value} -> true
      end
    end)
  end

  @spec apply_changeset_to_multi(
          multi :: Multi.t(),
          changeset :: Changeset.t(),
          type :: object_type()
        ) :: Multi.t()
  defp apply_changeset_to_multi(%Multi{} = multi, %Changeset{} = changeset, type) do
    id = changeset.data.id

    multi
    |> Multi.insert_or_update({:update, id}, changeset)
    |> Multi.run({:index, id}, fn _, data ->
      case has_parent_changed?(changeset) do
        false ->
          nil

        true ->
          obj = Map.fetch!(data, {:update, id})
          :ok = Index.fix_index_tree(obj.id, type)
      end

      {:ok, nil}
    end)
  end

  @spec apply_edit_changeset(changeset :: Changeset.t(), type :: object_type()) ::
          {:error, Changeset.t(), String.t()} | {:ok, map()}
  def apply_edit_changeset(%Changeset{} = changeset, type) do
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

  # @spec apply_update_changeset(
  #         id_list :: list(integer),
  #         changeset :: Changeset.t(),
  #         fields :: MapSet.t(),
  #         type :: module()
  #       ) ::
  #         {:error, String.t()} | :ok
  # def apply_update_changeset(id_list, %Changeset{} = changeset, fields, type) do
  #   case Changeset.apply_action(changeset, :update) do
  #     {:error, error} ->
  #       {:error, "The changeset is invalid: #{inspect(error)}"}

  #     {:ok, obj} ->
  #       changes =
  #         Enum.reduce(fields, %{}, fn field_id, acc ->
  #           Map.put(acc, field_id, Map.fetch!(obj, field_id))
  #         end)

  #       apply_update_changes(id_list, changes, type)
  #   end
  # end

  #   @spec subst_string_values(msg :: String.t(), opts :: keyword()) :: String.t()
  #   defp subst_string_values(msg, opts) do
  #     Enum.reduce(opts, msg, fn {key, value}, acc ->
  #       String.replace(acc, "%{#{key}}", to_string(value))
  #     end)
  #   end

  #   @spec errors_to_strings(changeset :: Changeset.t()) :: %{atom() => list(String.t())}
  #   defp errors_to_strings(changeset) do
  #     Changeset.traverse_errors(changeset, fn {msg, opts} ->
  #       subst_string_values(msg, opts)
  #     end)
  #   end

  #   @spec apply_update_changes(id_list :: list(integer), changes :: map(), type :: object_type()) ::
  #           {:error, String.t()} | :ok
  #   def apply_update_changes(id_list, changes, type) do
  #     multi = Multi.new()
  #
  #     multi =
  #       Enum.reduce(id_list, multi, fn id, multi ->
  #         case get_object_by_id(id, type) do
  #           nil ->
  #             Multi.error(multi, {:error, id}, "Cannot find object #{id}")
  #
  #           obj ->
  #             obj_changeset = get_edit_changeset(obj, changes)
  #             apply_changeset_to_multi(multi, obj_changeset, type)
  #         end
  #       end)
  #
  #     case Repo.transaction(multi) do
  #       {:ok, _data} ->
  #         :ok
  #
  #       {:error, {:update, id}, changeset, _data} ->
  #         errors =
  #           errors_to_strings(changeset)
  #           |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
  #           |> Enum.join(", ")
  #
  #         {:error, "The update of id #{id} failed: #{errors}"}
  #
  #       {:error, {:index, id}, error, _data} ->
  #         {:error, "Error #{inspect(error)} while indexing id #{id}"}
  #
  #       {:error, {:error, id}, error, _data} ->
  #         {:error, "Error looking for #{id}: #{error}"}
  #     end
  #   end

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
