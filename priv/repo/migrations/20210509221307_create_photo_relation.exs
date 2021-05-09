defmodule PenguinMemories.Repo.Migrations.CreatePhotoRelation do
  use Ecto.Migration

  def change do
    create table(:pm_photo_relation) do
      add(:photo_1_id, references(:pm_photo, on_delete: :delete_all))
      add(:photo_2_id, references(:pm_photo, on_delete: :delete_all))
      add(:description_1, :text)
      add(:description_2, :text)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo_relation, [:photo_1_id]))
    create(index(:pm_photo_relation, [:photo_2_id]))
  end
end
