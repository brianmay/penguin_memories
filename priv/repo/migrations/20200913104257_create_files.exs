defmodule PenguinMemories.Repo.Migrations.CreateFiles do
  use Ecto.Migration

  def change do
    create table(:spud_photo_file) do
      add(:size_key, :string)
      add(:width, :integer)
      add(:height, :integer)
      add(:dir, :string)
      add(:name, :string)
      add(:mime_type, :string)
      add(:is_video, :boolean, default: false, null: false)
      add(:sha256_hash, :binary)
      add(:num_bytes, :integer)
      add(:photo_id, references(:spud_photo, on_delete: :delete_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:spud_photo_file, [:photo_id, :size_key, :mime_type], unique: true))
    create(index(:spud_photo_file, [:dir, :name], unique: true))
    create(index(:spud_photo_file, [:size_key, :sha256_hash, :num_bytes]))
  end
end
