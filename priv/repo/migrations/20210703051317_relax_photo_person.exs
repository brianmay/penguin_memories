defmodule PenguinMemories.Repo.Migrations.RelaxPhotoPerson do
  use Ecto.Migration

  def change do
    drop(index(:pm_photo_person, [:photo_id, :position], unique: true))
    create(index(:pm_photo_person, [:photo_id, :position]))
  end
end
