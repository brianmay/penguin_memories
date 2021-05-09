defmodule PenguinMemories.Repo.Migrations.CreateFiles do
  use Ecto.Migration

  def change do
    create table(:pm_photo_file) do
      add(:size_key, :string, null: false)
      add(:width, :integer, null: false)
      add(:height, :integer, null: false)
      add(:dir, :string, null: false)
      add(:name, :string, null: false)
      add(:mime_type, :string, null: false)
      add(:is_video, :boolean, default: false, null: false)
      add(:sha256_hash, :binary, null: false)
      add(:num_bytes, :bigint, null: false)
      add(:photo_id, references(:pm_photo, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo_file, [:photo_id, :size_key, :mime_type], unique: true))
    create(index(:pm_photo_file, [:dir, :name], unique: true))
    create(index(:pm_photo_file, [:size_key, :sha256_hash, :num_bytes]))
  end
end
