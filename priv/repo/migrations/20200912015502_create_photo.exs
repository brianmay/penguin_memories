defmodule PenguinMemories.Repo.Migrations.CreatePhoto do
  use Ecto.Migration

  def change do
    create table(:spud_photo) do
      add(:comment, :text)
      add(:rating, :float)
      add(:flash_used, :text)
      add(:metering_mode, :text)
      add(:datetime, :utc_datetime)
      add(:size, :integer)
      add(:compression, :string)
      add(:title, :string)
      add(:photographer_id, :integer)
      add(:place_id, :integer)
      add(:aperture, :string)
      add(:ccd_width, :string)
      add(:description, :string)
      add(:iso_equiv, :string)
      add(:focal_length, :string)
      add(:path, :string)
      add(:exposure, :string)
      add(:name, :string)
      add(:level, :integer)
      add(:camera_make, :string)
      add(:camera_model, :string)
      add(:focus_dist, :string)
      add(:action, :string)
      add(:view, :string)
      add(:utc_offset, :integer)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:spud_photo, [:path, :name], unique: true))
    create(index(:spud_photo, [:place_id]))
    create(index(:spud_photo, [:datetime]))
    create(index(:spud_photo, [:action]))
  end
end
