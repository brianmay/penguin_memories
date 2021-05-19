defmodule PenguinMemories.Database.Impl.Backend.Photo do
  @moduledoc """
  Backend Photo functions
  """
  import Ecto.Query
  alias PenguinMemories.Database.Format
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Details
  alias PenguinMemories.Database.Query.Field
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo

  @behaviour API

  @impl API
  @spec get_single_name :: String.t()
  def get_single_name, do: "photo"

  @impl API
  @spec get_plural_name :: String.t()
  def get_plural_name, do: "photos"

  @impl API
  @spec get_cursor_fields :: list(atom())
  def get_cursor_fields, do: [:datetime, :id]

  @impl API
  @spec get_parent_fields :: list(atom())
  def get_parent_fields, do: []

  @impl API
  @spec get_index_type :: module() | nil
  def get_index_type, do: nil

  @impl API
  @spec query :: Ecto.Query.t()
  def query do
    from o in Photo,
      as: :object,
      select: %{
        datetime: o.datetime,
        id: o.id,
        o: %{action: o.action, title: o.title, dir: o.dir, name: o.name, utc_offset: o.utc_offset}
      },
      order_by: [asc: o.datetime, asc: o.id]
  end

  @impl API
  @spec filter_by_photo_id(query :: Ecto.Query.t(), photo_id :: integer) :: Ecto.Query.t()
  def filter_by_photo_id(%Ecto.Query{} = query, photo_id) do
    from [object: o] in query,
      where: o.id == ^photo_id
  end

  @impl API
  @spec filter_by_parent_id(query :: Ecto.Query.t(), parent_id :: integer) :: Ecto.Query.t()
  def filter_by_parent_id(%Ecto.Query{} = query, _) do
    query
  end

  @impl API
  @spec filter_by_reference(query :: Ecto.Query.t(), reference :: {module(), integer()}) ::
          Ecto.Query.t()
  def filter_by_reference(%Ecto.Query{} = query, {PenguinMemories.Photos.Album, id}) do
    from [object: o] in query,
      join: op in PenguinMemories.Photos.PhotoAlbum,
      on: op.photo_id == o.id,
      where: op.album_id == ^id
  end

  def filter_by_reference(%Ecto.Query{} = query, {PenguinMemories.Photos.Category, id}) do
    from [object: o] in query,
      join: op in PenguinMemories.Photos.PhotoCategory,
      on: op.photo_id == o.id,
      where: op.category_id == ^id
  end

  def filter_by_reference(%Ecto.Query{} = query, {PenguinMemories.Photos.Person, id}) do
    from [object: o] in query,
      join: op in PenguinMemories.Photos.PhotoPerson,
      on: op.photo_id == o.id,
      where: op.person_id == ^id
  end

  def filter_by_reference(%Ecto.Query{} = query, {PenguinMemories.Photos.Place, id}) do
    from [object: o] in query,
      where: o.place_id == ^id
  end

  def filter_by_reference(%Ecto.Query{} = query, _) do
    query
  end

  @impl API
  @spec get_title_from_result(result :: map()) :: String.t()
  def get_title_from_result(%{} = result) do
    case result.o.title do
      nil -> Path.join([result.o.dir, result.o.name])
      title -> title
    end
  end

  @impl API
  @spec get_subtitle_from_result(result :: map()) :: String.t()
  def get_subtitle_from_result(%{} = result) do
    Format.display_datetime_offset(result.datetime, result.o.utc_offset)
  end

  @impl API
  @spec get_details_from_result(
          result :: map(),
          icon_size :: String.t(),
          video_size :: String.t()
        ) :: Details.t()
  def get_details_from_result(%{} = result, icon_size, video_size) do
    icon = Query.get_icon_from_result(result, Photo)
    videos = Query.get_videos_for_photo(result.o.id, video_size)

    albums =
      Query.query(PenguinMemories.Photos.Album)
      |> filter_by_photo_id(result.o.id)
      |> Query.get_icons(icon_size)
      |> Repo.all()
      |> Enum.map(fn r -> Query.get_icon_from_result(r, PenguinMemories.Photos.Album) end)

    o = result.o

    fields = [
      %Field{
        id: :title,
        title: "Title",
        display: o.title,
        type: :string
      },
      %Field{
        id: :path,
        title: "Path",
        display: Path.join([o.dir, o.name]),
        type: :readonly
      },
      %Field{
        id: :album_list,
        title: "Albums",
        display: o.album_list,
        icons: albums,
        type: :albums
      },
      %Field{
        id: :photographer_id,
        title: "Photographer",
        display: o.photographer_id,
        type: :person
      },
      %Field{
        id: :place_id,
        title: "Place",
        display: o.place_id,
        type: :place
      },
      %Field{
        id: :view,
        title: "View",
        display: o.view,
        type: :string
      },
      %Field{
        id: :rating,
        title: "Rating",
        display: o.rating,
        type: :string
      },
      %Field{
        id: :description,
        title: "Description",
        display: o.description,
        type: :markdown
      },
      %Field{
        id: :private_notes,
        title: "Private Notes",
        display: o.private_notes,
        type: :markdown
      },
      %Field{
        id: :datetime,
        title: "Time",
        display: Format.display_datetime_offset(o.datetime, o.utc_offset),
        type: :datetime
      },
      %Field{
        id: :utc_offset,
        title: "UTC offset",
        display: o.utc_offset,
        type: :string
      },
      %Field{
        id: :action,
        title: "Action",
        display: o.action,
        type: :string
      },
      %Field{
        id: :camera_make,
        title: "Camera Make",
        display: o.camera_make,
        type: :readonly
      },
      %Field{
        id: :camera_model,
        title: "Camera Model",
        display: o.camera_model,
        type: :readonly
      },
      %Field{
        id: :flash_used,
        title: "Flash Used",
        display: o.flash_used,
        type: :readonly
      },
      %Field{
        id: :focal_length,
        title: "Focal Length",
        display: o.focal_length,
        type: :readonly
      },
      %Field{
        id: :exposure_time,
        title: "Exposure Time",
        display: o.exposure_time,
        type: :readonly
      },
      %Field{
        id: :aperture,
        title: "Aperture",
        display: o.aperture,
        type: :readonly
      },
      %Field{
        id: :iso_equiv,
        title: "ISO",
        display: o.iso_equiv,
        type: :readonly
      },
      %Field{
        id: :metering_mode,
        title: "Metering Mode",
        display: o.metering_mode,
        type: :readonly
      },
      %Field{
        id: :focus_dist,
        title: "Focus Distance",
        display: o.focus_dist,
        type: :readonly
      },
      %Field{
        id: :ccd_width,
        title: "CCD Width",
        display: o.ccd_width,
        type: :readonly
      }
    ]

    cursor = Paginator.cursor_for_record(result, get_cursor_fields())

    %Details{
      obj: result.o,
      icon: icon,
      videos: videos,
      fields: fields,
      cursor: cursor,
      type: Photo
    }
  end

  @impl API
  @spec get_update_fields() :: list(Field.t())
  def get_update_fields do
    [
      %Field{
        id: :title,
        title: "Title",
        display: nil,
        type: :string
      },
      %Field{
        id: :photographer_id,
        title: "Photographer",
        display: nil,
        type: :person
      },
      %Field{
        id: :place_id,
        title: "Place",
        display: nil,
        type: :place
      },
      %Field{
        id: :view,
        title: "View",
        display: nil,
        type: :string
      },
      %Field{
        id: :rating,
        title: "Rating",
        display: nil,
        type: :string
      },
      %Field{
        id: :description,
        title: "Description",
        display: nil,
        type: :string
      },
      %Field{
        id: :private_notes,
        title: "Private Notes",
        display: nil,
        type: :string
      },
      %Field{
        id: :datetime,
        title: "Time",
        display: nil,
        type: :time
      },
      %Field{
        id: :utc_offset,
        title: "Revised UTC offset",
        display: nil,
        type: :string
      },
      %Field{
        id: :action,
        title: "Action",
        display: nil,
        type: :string
      }
    ]
  end
end
