defmodule PenguinMemories.Photos.Album do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  alias PenguinMemories.Photos.Photo

  @type t :: map()
  schema "spud_album" do
    field :description, :string
    field :revised, :utc_datetime
    field :revised_utc_offset, :integer
    field :sort_name, :string
    field :sort_order, :string
    field :title, :string
    belongs_to :parent, PenguinMemories.Photos.Album
    has_many :children, PenguinMemories.Photos.Album, foreign_key: :parent_id
    belongs_to :cover_photo, Photo
    has_many :ascendants, PenguinMemories.Photos.AlbumAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.AlbumAscendant, foreign_key: :ascendant_id
  end

  @spec validate_pair(Changeset.t(), atom(), atom()) :: Changeset.t()
  defp validate_pair(%Changeset{} = changeset, key1, key2) do
    value1 = get_field(changeset, key1)
    value2 = get_field(changeset, key2)

    string1 = Atom.to_string(key1)
    string2 = Atom.to_string(key2)

    case {value1, value2}  do
      {nil, nil} ->
        changeset

      {_, nil} ->
        add_error(changeset, key2, "If #{string1} supplied then #{string2} must be supplied too")

      {nil, _} ->
        add_error(changeset, key1, "If #{string2} supplied then #{string1} must be supplied too")

      {_, _} ->
        changeset

    end
  end

  @spec validate_revised(Changeset.t()) :: Changeset.t()
  defp validate_revised(%Changeset{data: %__MODULE__{}} = changeset) do
    validate_pair(changeset, :revised, :revised_utc_offset)
  end

  @spec edit_changeset(t(), map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = album, attrs) do
    album
    |> cast(attrs, [:title, :parent_id, :revised, :sort_name, :cover_photo_id, :description, :sort_order, :revised_utc_offset])
    |> validate_required([:title, :sort_name, :sort_order])
    |> validate_revised()
  end

  @spec update_changeset(t(), MapSet.t(), map()) :: Changeset.t()
  def update_changeset(%__MODULE__{} = album, enabled, attrs) do
    enabled_list = MapSet.to_list(enabled)
    required = MapSet.new([:title, :sort_name, :sort_order])
    required_list = MapSet.to_list(
      MapSet.intersection(enabled, required)
    )

    album
    |> cast(attrs, enabled_list)
    |> validate_required(required_list)
  end

end
