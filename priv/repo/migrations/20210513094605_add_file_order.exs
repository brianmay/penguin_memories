defmodule PenguinMemories.Repo.Migrations.AddFileOrder do
  use Ecto.Migration

  def change do
    create table(:pm_photo_file_order) do
      add(:size_key, :text, null: false)
      add(:mime_type, :text, null: false)
      add(:order, :integer, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo_file_order, [:size_key, :mime_type], unique: true))
  end
end
