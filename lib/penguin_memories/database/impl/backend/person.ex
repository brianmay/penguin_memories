defmodule PenguinMemories.Database.Impl.Backend.Person do
  @moduledoc """
  Backend Person functions
  """
  alias Ecto.Changeset
  import Ecto.Changeset
  import Ecto.Query

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Fields.UpdateField
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Impl.Backend.Private
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Person
  alias PenguinMemories.Photos.PersonAscendant
  alias PenguinMemories.Photos.PersonUpdate
  alias PenguinMemories.Photos.PhotoPerson
  alias PenguinMemories.Photos.Place
  alias PenguinMemories.Repo

  @behaviour API

  @impl API
  @spec get_single_name :: String.t()
  def get_single_name, do: "person"

  @impl API
  @spec get_plural_name :: String.t()
  def get_plural_name, do: "people"

  @impl API
  @spec get_cursor_fields :: list(atom())
  def get_cursor_fields, do: [:sort_name, :name, :id]

  @impl API
  @spec get_parent_fields :: list(atom())
  def get_parent_fields, do: [:mother, :father]

  @impl API
  @spec get_parent_id_fields :: list(atom())
  def get_parent_id_fields, do: [:mother_id, :father_id]

  @impl API
  @spec get_index_type :: module() | nil
  def get_index_type, do: PersonAscendant

  @impl API
  @spec query :: Ecto.Query.t()
  def query do
    from o in Person,
      as: :object,
      select: %{sort_name: o.sort_name, id: o.id, o: %{name: o.name}},
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
  def filter_by_reference(%Ecto.Query{} = query, {Person, id}) do
    filter_by_parent_id(query, id)
  end

  def filter_by_reference(%Ecto.Query{} = query, _) do
    query
  end

  @impl API
  @spec preload_details(query :: Ecto.Query.t()) :: Ecto.Query.t()
  def preload_details(query) do
    preload(query, [:cover_photo, :home, :work, :mother, :father, :spouse, :mother_of, :father_of])
  end

  @impl API
  @spec preload_details_from_results(results :: list(struct())) :: list(struct())
  def preload_details_from_results(results) do
    Repo.preload(results, [
      :cover_photo,
      :home,
      :work,
      :mother,
      :father,
      :spouse,
      :mother_of,
      :father_of
    ])
  end

  @impl API
  @spec get_title_from_result(result :: map()) :: String.t()
  def get_title_from_result(%{} = result) do
    "#{result.o.name}"
  end

  @impl API
  @spec get_subtitle_from_result(result :: map()) :: String.t() | nil
  def get_subtitle_from_result(%{} = result) do
    "#{result.sort_name}"
  end

  @impl API
  @spec get_details_from_result(
          result :: map(),
          icon_size :: String.t(),
          video_size :: String.t()
        ) :: Query.Details.t()
  def get_details_from_result(%{} = result, _icon_size, _video_size) do
    icon = Query.get_icon_from_result(result, Person)
    orig = Query.get_orig_from_result(result, Person)
    cursor = Paginator.cursor_for_record(result, get_cursor_fields())

    %Query.Details{
      obj: result.o,
      icon: icon,
      orig: orig,
      videos: [],
      cursor: cursor,
      type: Person
    }
  end

  @impl API
  @spec get_fields :: list(Field.t())
  def get_fields do
    [
      %Field{
        id: :id,
        name: "ID",
        type: :integer,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :name,
        name: "Name",
        type: :string,
        searchable: true
      },
      %Field{
        id: :sort_name,
        name: "Sort Name",
        type: :string,
        searchable: true
      },
      %Field{
        id: :mother,
        name: "Mother",
        type: {:single, Person},
        searchable: true
      },
      %Field{
        id: :father,
        name: "Father",
        type: {:single, Person},
        searchable: true
      },
      %Field{
        id: :mother_of,
        name: "Mother of",
        type: {:multiple, Person},
        read_only: true
      },
      %Field{
        id: :father_of,
        name: "Father of",
        type: {:multiple, Person},
        read_only: true
      },
      %Field{
        id: :spouse,
        name: "Spouse",
        type: {:single, Person},
        searchable: true
      },
      %Field{
        id: :home,
        name: "Home",
        type: {:single, Place},
        searchable: true
      },
      %Field{
        id: :work,
        name: "Work",
        type: {:single, Place},
        searchable: true
      },
      %Field{
        id: :email,
        name: "E-Mail",
        type: :string,
        access: :private
      },
      %Field{
        id: :description,
        name: "Description",
        type: :markdown
      },
      %Field{
        id: :private_notes,
        name: "Private Notes",
        type: :markdown,
        access: :private
      },
      %Field{
        id: :cover_photo,
        name: "Cover Photo",
        type: {:single, PenguinMemories.Photos.Photo},
        searchable: true
      },
      %Field{
        id: :revised,
        name: "Revised time",
        type: :datetime,
        searchable: true
      }
    ]
  end

  @impl API
  @spec get_update_fields :: list(UpdateField.t())
  def get_update_fields do
    [
      %UpdateField{
        id: :mother,
        field_id: :mother,
        name: "Mother",
        type: {:single, Person},
        change: :set
      },
      %UpdateField{
        id: :father,
        field_id: :father,
        name: "Father",
        type: {:single, Person},
        change: :set
      },
      %UpdateField{
        id: :spouse,
        field_id: :spouse,
        name: "Spouse",
        type: {:single, Person},
        change: :set
      },
      %UpdateField{
        id: :home,
        field_id: :home,
        name: "Home",
        type: {:single, Place},
        change: :set
      },
      %UpdateField{
        id: :work,
        field_id: :work,
        name: "Work",
        type: {:single, Place},
        change: :set
      },
      %UpdateField{
        id: :revised,
        field_id: :revised,
        name: "Revised time",
        type: :datetime,
        change: :set
      }
    ]
  end

  @impl API
  @spec edit_changeset(object :: Person.t(), attrs :: map(), assoc :: map()) :: Changeset.t()
  def edit_changeset(%Person{} = person, attrs, assoc) do
    person
    |> cast(attrs, [
      :cover_photo_id,
      :name,
      :called,
      :sort_name,
      :date_of_birth,
      :date_of_death,
      :description,
      :private_notes,
      :email,
      :revised
    ])
    |> validate_required([:name, :sort_name])
    |> Private.put_all_assoc(assoc, [:mother, :father, :spouse, :work, :home, :cover_photo])
  end

  @impl API
  @spec update_changeset(
          attrs :: map(),
          assoc :: map(),
          enabled :: MapSet.t()
        ) ::
          Changeset.t()
  def update_changeset(attrs, assoc, enabled) do
    %PersonUpdate{mother: nil, father: nil, spouse: nil, home: nil, work: nil}
    |> Private.selective_cast(attrs, enabled, [:revised])
    |> Private.selective_put_assoc(assoc, enabled, [
      :mother,
      :father,
      :spouse,
      :work,
      :home
    ])
  end
end
