defmodule PenguinMemories.Photos.Album do
  use Ecto.Schema
  import Ecto.Changeset

  alias PenguinMemories.Photos.Photo
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
  end

  @doc false
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:title, :revised, :sort_name, :cover_photo_id, :description, :sort_order, :revised_utc_offset])
    |> validate_required([:title, :revised, :sort_name, :cover_photo_id, :description, :sort_order, :revised_utc_offset])
  end
end
