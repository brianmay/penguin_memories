defmodule PenguinMemories.Repo.Migrations.CreatePhoto do
  use Ecto.Migration

  def change do
    create table(:pm_photo) do
      add(:title, :text)
      add(:rating, :float)
      add(:action, :text)
      add(:description, :text)
      add(:private_notes, :text)
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
      add(:exposure_time, :float)
      add(:camera_make, :text)
      add(:camera_model, :text)
      add(:focus_dist, :float)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo, [:title]))
    create(index(:pm_photo, [:rating]))
    create(index(:pm_photo, [:action]))

    # date/time
    create(index(:pm_photo, [:datetime]))
    create(index(:pm_photo, [:utc_offset]))

    # filesystem - used for creating new image files
    create(index(:pm_photo, [:dir, :name]))
    create(index(:pm_photo, [:name]))

    # exif values
    create(index(:pm_photo, [:aperture]))
    create(index(:pm_photo, [:flash_used]))
    create(index(:pm_photo, [:metering_mode]))
    create(index(:pm_photo, [:ccd_width]))
    create(index(:pm_photo, [:iso_equiv]))
    create(index(:pm_photo, [:focal_length]))
    create(index(:pm_photo, [:exposure_time]))
    create(index(:pm_photo, [:camera_make]))
    create(index(:pm_photo, [:camera_model]))
    create(index(:pm_photo, [:focus_dist]))
  end
end
