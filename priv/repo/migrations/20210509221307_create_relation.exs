defmodule PenguinMemories.Repo.Migrations.CreatePhotoRelation do
  use Ecto.Migration

  def change do
    create table(:pm_relation) do
      add(:name, :text, null: false)
      add(:description, :text)
      add(:private_notes, :text)
      timestamps(type: :utc_datetime_usec)
    end

    create table(:pm_photo_relation) do
      add(:photo_id, references(:pm_photo, on_delete: :delete_all), null: false)
      add(:relation_id, references(:pm_relation, on_delete: :delete_all), null: false)
      add(:name, :text, null: false)
      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo_relation, [:photo_id, :relation_id], unique: true))
    create(index(:pm_photo_relation, [:relation_id]))
  end
end
