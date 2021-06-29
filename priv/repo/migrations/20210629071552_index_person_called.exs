defmodule PenguinMemories.Repo.Migrations.IndexPersonCalled do
  use Ecto.Migration

  def change do
    create(index(:pm_person, [:called]))
  end
end
