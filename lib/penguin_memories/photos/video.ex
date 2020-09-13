defmodule PenguinMemories.Photos.Video do
  use Ecto.Schema
  import Ecto.Changeset

  schema "spud_photo_video" do
    field :extension, :string
    field :format, :string
    field :height, :integer
    field :size, :string
    field :width, :integer
    belongs_to :photo, Photo
  end

  @doc false
  def changeset(video, attrs) do
    video
    |> cast(attrs, [:height, :width, :size, :format, :extension])
    |> validate_required([:height, :width, :size, :format, :extension])
  end
end
