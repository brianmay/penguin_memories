defmodule PenguinMemories.Repo.Migrations.AddPhotoReferences do
  use Ecto.Migration

  def change do
    alter table(:pm_photo) do
      add(:photographer_id, references(:pm_person, on_delete: :nilify_all))
      add(:place_id, references(:pm_place, on_delete: :nilify_all))
    end

    create(index(:pm_photo, [:photographer_id]))
    create(index(:pm_photo, [:place_id]))
  end
end
