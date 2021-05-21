defmodule PenguinMemories.Database.Impl.Backend.Photo do
  @moduledoc """
  Backend Photo functions
  """
  import Ecto.Query
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Details
  alias PenguinMemories.Database.Query.Field
  alias PenguinMemories.Format
  alias PenguinMemories.Photos.Photo

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
  @spec preload_details(query :: Ecto.Query.t()) :: Ecto.Query.t()
  def preload_details(query) do
    preload(query, [:albums, :categorys, :place, :photographer])
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
  def get_details_from_result(%{} = result, _icon_size, video_size) do
    icon = Query.get_icon_from_result(result, Photo)
    videos = Query.get_videos_for_photo(result.o.id, video_size)

    o = result.o

    fields = [
      %Field{
        id: :title,
        title: "Title",
        type: :string
      },
      %Field{
        id: :path,
        title: "Path",
        type: {:static, Path.join([o.dir, o.name])},
        read_only: true
      },
      %Field{
        id: :albums,
        title: "Albums",
        type: {:multiple, PenguinMemories.Photos.Album}
      },
      %Field{
        id: :categorys,
        title: "Categories",
        type: {:multiple, PenguinMemories.Photos.Category}
      },
      %Field{
        id: :place,
        title: "Place",
        type: {:single, PenguinMemories.Photos.Place}
      },
      %Field{
        id: :photographer,
        title: "Photographer",
        type: {:single, PenguinMemories.Photos.Person}
      },
      %Field{
        id: :view,
        title: "View",
        type: :string
      },
      %Field{
        id: :rating,
        title: "Rating",
        type: :string
      },
      %Field{
        id: :description,
        title: "Description",
        type: :markdown
      },
      %Field{
        id: :private_notes,
        title: "Private Notes",
        type: :markdown
      },
      %Field{
        id: :datetime,
        title: "Time",
        type: {:datetime_with_offset, o.utc_offset}
      },
      %Field{
        id: :utc_offset,
        title: "UTC offset",
        type: :utc_offset
      },
      %Field{
        id: :action,
        title: "Action",
        type: :string
      },
      %Field{
        id: :camera_make,
        title: "Camera Make",
        type: :string,
        read_only: true
      },
      %Field{
        id: :camera_model,
        title: "Camera Model",
        type: :string,
        read_only: true
      },
      %Field{
        id: :flash_used,
        title: "Flash Used",
        type: :string,
        read_only: true
      },
      %Field{
        id: :focal_length,
        title: "Focal Length",
        type: :string,
        read_only: true
      },
      %Field{
        id: :exposure_time,
        title: "Exposure Time",
        type: :string,
        read_only: true
      },
      %Field{
        id: :aperture,
        title: "Aperture",
        type: :string,
        read_only: true
      },
      %Field{
        id: :iso_equiv,
        title: "ISO",
        type: :string,
        read_only: true
      },
      %Field{
        id: :metering_mode,
        title: "Metering Mode",
        type: :string,
        read_only: true
      },
      %Field{
        id: :focus_dist,
        title: "Focus Distance",
        type: :string,
        read_only: true
      },
      %Field{
        id: :ccd_width,
        title: "CCD Width",
        type: :string,
        read_only: true
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
        type: :string
      },
      %Field{
        id: :photographer,
        title: "Photographer",
        type: {:single, PenguinMemories.Photos.Person}
      },
      %Field{
        id: :place,
        title: "Place",
        type: {:single, PenguinMemories.Photos.Place}
      },
      %Field{
        id: :view,
        title: "View",
        type: :string
      },
      %Field{
        id: :rating,
        title: "Rating",
        type: :string
      },
      %Field{
        id: :description,
        title: "Description",
        type: :string
      },
      %Field{
        id: :private_notes,
        title: "Private Notes",
        type: :string
      },
      %Field{
        id: :datetime,
        title: "Time",
        type: :time
      },
      %Field{
        id: :utc_offset,
        title: "Revised UTC offset",
        type: :utc_offset
      },
      %Field{
        id: :action,
        title: "Action",
        type: :string
      }
    ]
  end
end
