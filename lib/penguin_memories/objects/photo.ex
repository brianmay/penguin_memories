defmodule PenguinMemories.Objects.Photo do
  @moduledoc """
  Photo specific functions.
  """
  import Ecto.Query
  alias Ecto.Changeset
  alias Ecto.Multi

  alias PenguinMemories.Objects
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.FileOrder
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo

  @behaviour Objects

  @spec get_image_url() :: String.t()
  defp get_image_url do
    Application.get_env(:penguin_memories, :image_url)
  end

  @impl Objects
  @spec get_type_name() :: String.t()
  def get_type_name do
    "photo"
  end

  @impl Objects
  @spec get_plural_title() :: String.t()
  def get_plural_title do
    "photos"
  end

  @spec query_common :: Ecto.Query.t()
  defp query_common do
    from o in Photo,
      as: :object,
      select: %{id: o.id, datetime: o.datetime},
      order_by: [asc: o.datetime, asc: o.id]
  end

  @spec filter_album_id(Ecto.Query.t(), integer) :: Ecto.Query.t()
  defp filter_album_id(query, album_id) do
    case album_id do
      nil ->
        query

      id ->
        from [object: o] in query,
          join: album in assoc(o, :albums),
          where: album.id == ^id
    end
  end

  @spec filter_query(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  defp filter_query(query, query_string) do
    case query_string do
      nil ->
        query

      search ->
        filtered_search = ["%", String.replace(search, "%", ""), "%"]
        filtered_search = Enum.join(filtered_search)
        dynamic = dynamic([o], ilike(o.title, ^filtered_search))
        dynamic = dynamic([o], ^dynamic or ilike(o.name, ^filtered_search))

        dynamic =
          case Integer.parse(search) do
            {int, ""} -> dynamic([o], ^dynamic or o.id == ^int)
            _ -> dynamic
          end

        from [object: o] in query, where: ^dynamic
    end
  end

  @spec query_objects(%{required(String.t()) => String.t()}) :: Ecto.Query.t()
  defp query_objects(%{"ids" => id_mapset}) when not is_nil(id_mapset) do
    id_list = MapSet.to_list(id_mapset)

    from [object: o] in query_common(),
      where: o.id in ^id_list
  end

  defp query_objects(filter_spec) do
    query_common()
    |> filter_album_id(filter_spec["album"])
    |> filter_query(filter_spec["query"])
  end

  @spec query_object(integer) :: Ecto.Query.t()
  defp query_object(id) do
    from [object: o] in query_common(),
      where: o.id == ^id
  end

  @spec query_icons(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  defp query_icons(query, size) do
    file_query =
      from f in File,
        where: f.size_key == ^size and f.is_video == false,
        join: j in FileOrder,
        on: j.size_key == ^size and j.mime_type == f.mime_type,
        distinct: f.photo_id,
        order_by: [asc: j.order]

    query =
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

    query
  end

  @spec query_videos(integer(), String.t()) :: list(Objects.Video.t())
  defp query_videos(photo_id, size) do
    file_query =
      from f in File,
        where: f.size_key == ^size and f.is_video == true and f.photo_id == ^photo_id,
        join: j in FileOrder,
        on: j.size_key == ^size and j.mime_type == f.mime_type,
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

      %Objects.Video{
        url: url,
        height: result.height,
        width: result.width,
        mime_type: result.mime_type,
        type: __MODULE__
      }
    end)
  end

  @spec get_icon_from_result(map()) :: Objects.Icon.t()
  defp get_icon_from_result(result) do
    url =
      if result.icon.dir do
        "#{get_image_url()}/#{result.icon.dir}/#{result.icon.name}"
      end

    subtitle = Objects.display_datetime_offset(result.datetime, result.icon.utc_offset)

    %Objects.Icon{
      id: result.id,
      action: result.icon.action,
      url: url,
      title: result.icon.title,
      subtitle: subtitle,
      height: result.icon.height,
      width: result.icon.width,
      type: __MODULE__
    }
  end

  @impl Objects
  @spec get_parent_ids(integer) :: list(integer())
  def get_parent_ids(id) when is_integer(id) do
    query =
      from [object: o] in Photo,
        where: o.id == ^id,
        select: o.parent_id

    case Repo.one!(query) do
      nil -> []
      id -> [id]
    end
  end

  @impl Objects
  @spec get_child_ids(integer) :: list(integer())
  def get_child_ids(id) do
    query =
      from [object: o] in Photo,
        where: o.parent_id == ^id,
        select: o.id

    Repo.all(query)
  end

  @impl Objects
  @spec get_index(integer) :: list(MapSet.t())
  def get_index(_id) do
    []
  end

  @impl Objects
  @spec create_index(integer, {integer, integer}) :: :ok
  def create_index(_id, _index) do
    :ok
  end

  @impl Objects
  @spec delete_index(integer, {integer, integer}) :: :ok
  def delete_index(_id, _index) do
    :ok
  end

  @impl Objects
  @spec get_update_fields() :: list(Objects.Field.t())
  def get_update_fields do
    [
      %Objects.Field{
        id: :title,
        title: "Title",
        display: nil,
        type: :string
      },
      %Objects.Field{
        id: :photographer_id,
        title: "Photographer",
        display: nil,
        type: :person
      },
      %Objects.Field{
        id: :place_id,
        title: "Place",
        display: nil,
        type: :place
      },
      %Objects.Field{
        id: :view,
        title: "View",
        display: nil,
        type: :string
      },
      %Objects.Field{
        id: :rating,
        title: "Rating",
        display: nil,
        type: :string
      },
      %Objects.Field{
        id: :description,
        title: "Description",
        display: nil,
        type: :string
      },
      %Objects.Field{
        id: :private_notes,
        title: "Private Notes",
        display: nil,
        type: :string
      },
      %Objects.Field{
        id: :datetime,
        title: "Time",
        display: nil,
        type: :time
      },
      %Objects.Field{
        id: :utc_offset,
        title: "Revised UTC offset",
        display: nil,
        type: :string
      },
      %Objects.Field{
        id: :action,
        title: "Action",
        display: nil,
        type: :string
      }
    ]
  end

  @impl Objects
  @spec get_parents(integer) :: list({Objects.Icon.t(), integer})
  def get_parents(_id) do
    []
  end

  @impl Objects
  @spec get_details(integer, String.t(), String.t()) ::
          {map(), Objects.Icon.t(), list(Objects.Video.t()), list(Objects.Field.t()), String.t()}
          | nil
  def get_details(id, icon_size, video_size) do
    query =
      id
      |> query_object()
      |> query_icons(icon_size)
      |> select_merge([object: o], %{o: o})

    # |> preload([:photo_albums])

    case Repo.one(query) do
      nil ->
        nil

      result ->
        id = result.o.id
        icon = get_icon_from_result(result)
        albums = PenguinMemories.Objects.Album.search_icons(%{"photo_id" => id}, 10)
        videos = query_videos(id, video_size)

        album_list =
          albums
          |> Enum.map(fn album -> album.id end)
          |> Enum.join(",")

        o = %{result.o | album_list: album_list}

        fields = [
          %Objects.Field{
            id: :title,
            title: "Title",
            display: o.title,
            type: :string
          },
          %Objects.Field{
            id: :album_list,
            title: "Albums",
            display: o.album_list,
            icons: albums,
            type: :albums
          },
          %Objects.Field{
            id: :photographer_id,
            title: "Photographer",
            display: o.photographer_id,
            type: :person
          },
          %Objects.Field{
            id: :place_id,
            title: "Place",
            display: o.place_id,
            type: :place
          },
          %Objects.Field{
            id: :view,
            title: "View",
            display: o.view,
            type: :string
          },
          %Objects.Field{
            id: :rating,
            title: "Rating",
            display: o.rating,
            type: :string
          },
          %Objects.Field{
            id: :description,
            title: "Description",
            display: o.description,
            type: :markdown
          },
          %Objects.Field{
            id: :private_notes,
            title: "Private Notes",
            display: o.private_notes,
            type: :markdown
          },
          %Objects.Field{
            id: :datetime,
            title: "Time",
            display: Objects.display_datetime_offset(o.datetime, o.utc_offset),
            type: :datetime
          },
          %Objects.Field{
            id: :utc_offset,
            title: "Revised UTC offset",
            display: o.utc_offset,
            type: :string
          },
          %Objects.Field{
            id: :action,
            title: "Action",
            display: o.action,
            type: :string
          },
          %Objects.Field{
            id: :camera_make,
            title: "Camera Make",
            display: o.camera_make,
            type: :readonly
          },
          %Objects.Field{
            id: :camera_model,
            title: "Camera Model",
            display: o.camera_model,
            type: :readonly
          },
          %Objects.Field{
            id: :flash_used,
            title: "Flash Used",
            display: o.flash_used,
            type: :readonly
          },
          %Objects.Field{
            id: :focal_length,
            title: "Focal Length",
            display: o.focal_length,
            type: :readonly
          },
          %Objects.Field{
            id: :exposure_time,
            title: "Exposure Time",
            display: o.exposure_time,
            type: :readonly
          },
          %Objects.Field{
            id: :aperture,
            title: "Aperture",
            display: o.aperture,
            type: :readonly
          },
          %Objects.Field{
            id: :iso_equiv,
            title: "ISO",
            display: o.iso_equiv,
            type: :readonly
          },
          %Objects.Field{
            id: :metering_mode,
            title: "Metering Mode",
            display: o.metering_mode,
            type: :readonly
          },
          %Objects.Field{
            id: :focus_dist,
            title: "Focus Distance",
            display: o.focus_dist,
            type: :readonly
          },
          %Objects.Field{
            id: :ccd_width,
            title: "CCD Width",
            display: o.ccd_width,
            type: :readonly
          }
        ]

        cursor = Paginator.cursor_for_record(result, [:datetime, :id])
        {o, icon, videos, fields, cursor}
    end
  end

  @impl Objects
  @spec get_page_icons(
          %{required(String.t()) => String.t()},
          String.t() | nil,
          String.t() | nil,
          integer()
        ) :: {list(Objects.Icon.t()), String.t() | nil, String.t() | nil, integer}
  def get_page_icons(filter_spec, before_key, after_key, limit) do
    query =
      filter_spec
      |> query_objects()
      |> query_icons("thumb")

    %{entries: entries, metadata: metadata} =
      Repo.paginate(
        query,
        before: before_key,
        after: after_key,
        cursor_fields: [:datetime, :id],
        limit: limit
      )

    icons =
      Enum.map(entries, fn result ->
        get_icon_from_result(result)
      end)

    {icons, metadata.before, metadata.after, metadata.total_count}
  end

  @impl Objects
  @spec get_prev_next_id(
          %{required(String.t()) => String.t()},
          String.t() | nil,
          String.t() | nil
        ) :: nil | Objects.Icon.t()
  def get_prev_next_id(filter_spec, before_key, after_key) do
    query =
      filter_spec
      |> query_objects()
      |> query_icons("thumb")

    %{entries: entries, metadata: _} =
      Repo.paginate(
        query,
        before: before_key,
        after: after_key,
        cursor_fields: [:datetime, :id],
        limit: 1,
        include_total_count: false
      )

    case entries do
      [result] -> get_icon_from_result(result)
      [] -> nil
    end
  end

  @impl Objects
  @spec search_icons(%{required(String.t()) => String.t()}, integer) :: list(Objects.Icon.t())
  def search_icons(filter_spec, limit) do
    query =
      filter_spec
      |> query_objects()
      |> query_icons("thumb")
      |> limit(^limit)

    entries = Repo.all(query)

    Enum.map(entries, fn result ->
      get_icon_from_result(result)
    end)
  end

  @impl Objects
  @spec can_create? :: boolean()
  def can_create?, do: false

  @impl Objects
  @spec get_create_child_changeset(Photo.t(), map()) :: Ecto.Changeset.t()
  def get_create_child_changeset(%Photo{}, attrs) do
    %Photo{}
    |> Photo.edit_changeset(attrs)
  end

  @impl Objects
  @spec get_edit_changeset(map(), map()) :: Ecto.Changeset.t()
  def get_edit_changeset(album, attrs) do
    Photo.edit_changeset(album, attrs)
  end

  @impl Objects
  @spec get_update_changeset(MapSet.t(), map()) :: Ecto.Changeset.t()
  def get_update_changeset(enabled, attrs) do
    Photo.update_changeset(%Photo{}, enabled, attrs)
  end

  @impl Objects
  @spec has_parent_changed?(Changeset.t()) :: boolean
  def has_parent_changed?(%Changeset{data: %Photo{}} = _changeset) do
    false
  end

  @spec is_album_cover_photo?(integer) :: boolean
  def is_album_cover_photo?(id) do
    query = from o in Album, where: o.cover_photo_id == ^id
    Repo.exists?(query)
  end

  @impl Objects
  @spec can_delete?(integer) :: {:no, String.t()} | :yes
  def can_delete?(id) do
    cond do
      is_album_cover_photo?(id) ->
        {:no, "Cannot delete photo that is used by album cover photo"}

      true ->
        :yes
    end
  end

  @spec do_delete(Photo.t()) :: :ok | {:error, String.t()}
  defp do_delete(%Photo{} = object) do
    result =
      Multi.new()
      |> Multi.run(:object, fn _, _ ->
        object
        |> Ecto.Changeset.change(action: "D")
        |> Repo.update()
      end)
      |> Repo.transaction()

    case result do
      {:ok, _} ->
        :ok

      {:error, :object, _, _} ->
        {:error, "Cannot delete photo"}
    end
  end

  @impl Objects
  @spec delete(Photo.t()) :: :ok | {:error, String.t()}
  def delete(%Photo{} = object) do
    case can_delete?(object.id) do
      :yes -> do_delete(object)
      {:no, error} -> {:error, error}
    end
  end

  @impl Objects
  @spec get_photo_params(integer) :: map() | nil
  def get_photo_params(_id) do
    nil
  end
end
