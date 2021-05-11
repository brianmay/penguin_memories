defmodule PenguinMemories.Repo.Migrations.CreatePhoto do
  use Ecto.Migration

  def change do
    create table(:pm_photo) do
      add(:title, :text)
      add(:description, :text)
      add(:comment, :text)
      add(:rating, :float)
      add(:action, :text)
      add(:view, :text)
      # add(:photographer_id, :integer)
      # add(:place_id, :integer)

      # date/time
      add(:datetime, :utc_datetime, null: false)
      add(:utc_offset, :integer, null: false)

      # filesystem - used for creating new image files
      add(:dir, :text, null: false)
      add(:name, :text, null: false)

      # exif values
      add(:aperture, :float)
      add(:flash_used, :boolean)
      add(:metering_mode, :text)
      add(:ccd_width, :integer)
      add(:iso_equiv, :integer)
      add(:focal_length, :float)
      add(:exposure, :float)
      add(:camera_make, :text)
      add(:camera_model, :text)
      add(:focus_dist, :float)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo, [:dir, :name], unique: true))
    create(index(:pm_photo, [:datetime]))
    create(index(:pm_photo, [:action]))
  end
end
