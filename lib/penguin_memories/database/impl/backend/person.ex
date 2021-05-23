defmodule PenguinMemories.Database.Impl.Backend.Person do
  @moduledoc """
  Backend Person functions
  """
  import Ecto.Query
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Details
  alias PenguinMemories.Database.Query.Field
  alias PenguinMemories.Photos.Person
  alias PenguinMemories.Photos.PersonAscendant
  alias PenguinMemories.Photos.PhotoPerson
  alias PenguinMemories.Photos.Place

  @behaviour API

  @impl API
  @spec get_single_name :: String.t()
  def get_single_name, do: "person"

  @impl API
  @spec get_plural_name :: String.t()
  def get_plural_name, do: "people"

  @impl API
  @spec get_cursor_fields :: list(atom())
  def get_cursor_fields, do: [:sort_name, :id]

  @impl API
  @spec get_parent_fields :: list(atom())
  def get_parent_fields, do: [:mother_id, :father_id]

  @impl API
  @spec get_index_type :: module() | nil
  def get_index_type, do: PersonAscendant

  @impl API
  @spec query :: Ecto.Query.t()
  def query do
    from o in Person,
      as: :object,
      select: %{sort_name: o.sort_name, id: o.id, o: %{title: o.title}},
      order_by: [asc: o.sort_name, asc: o.id]
  end

  @impl API
  @spec filter_by_photo_id(query :: Ecto.Query.t(), photo_id :: integer) :: Ecto.Query.t()
  def filter_by_photo_id(%Ecto.Query{} = query, photo_id) do
    from [object: o] in query,
      join: op in PhotoPerson,
      on: op.album_id == o.id,
      where: op.photo_id == ^photo_id
  end

  @impl API
  @spec filter_by_parent_id(query :: Ecto.Query.t(), parent_id :: integer) :: Ecto.Query.t()
  def filter_by_parent_id(%Ecto.Query{} = query, parent_id) do
    from [object: o] in query, where: o.mother_id == ^parent_id or o.father_id == ^parent_id
  end

  @impl API
  @spec filter_by_reference(query :: Ecto.Query.t(), reference :: {module(), integer()}) ::
          Ecto.Query.t()
  def filter_by_reference(%Ecto.Query{} = query, {Album, id}) do
    filter_by_parent_id(query, id)
  end

  def filter_by_reference(%Ecto.Query{} = query, _) do
    query
  end

  @impl API
  @spec preload_details(query :: Ecto.Query.t()) :: Ecto.Query.t()
  def preload_details(query) do
    preload(query, [:cover_photo, :home, :work, :mother, :father, :spouse])
  end

  @impl API
  @spec get_title_from_result(result :: map()) :: String.t()
  def get_title_from_result(%{} = result) do
    "#{result.o.title}"
  end

  @impl API
  @spec get_subtitle_from_result(result :: map()) :: String.t()
  def get_subtitle_from_result(%{} = result) do
    "#{result.sort_name}"
  end

  @impl API
  @spec get_details_from_result(
          result :: map(),
          icon_size :: String.t(),
          video_size :: String.t()
        ) :: Details.t()
  def get_details_from_result(%{} = result, _icon_size, _video_size) do
    icon = Query.get_icon_from_result(result, Person)

    fields = [
      %Field{
        id: :title,
        title: "Title",
        type: :string
      },
      %Field{
        id: :mother,
        title: "Mother",
        type: {:single, Person}
      },
      %Field{
        id: :father,
        title: "Father",
        type: {:single, Person}
      },
      %Field{
        id: :spouse,
        title: "Spouse",
        type: {:single, Person}
      },
      %Field{
        id: :home,
        title: "Home",
        type: {:single, Place}
      },
      %Field{
        id: :work,
        title: "Work",
        type: {:single, Place}
      },
      %Field{
        id: :email,
        title: "E-Mail",
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
        id: :cover_photo,
        title: "Cover Photo",
        type: {:single, PenguinMemories.Photos.Photo}
      },
      %Field{
        id: :revised,
        title: "Revised time",
        type: :datetime
      }
    ]

    cursor = Paginator.cursor_for_record(result, get_cursor_fields())

    %Details{
      obj: result.o,
      icon: icon,
      videos: [],
      fields: fields,
      cursor: cursor,
      type: Person
    }
  end

  @impl API
  @spec get_update_fields :: list(Field.t())
  def get_update_fields do
    [
      %Field{
        id: :title,
        title: "Title",
        type: :string
      },
      %Field{
        id: :revised,
        title: "Revised time",
        type: :datetime
      }
    ]
  end
end
