defmodule PenguinMemories.Repo.Migrations.AddReindex do
  use Ecto.Migration

  def change do
    alter table(:pm_album) do
      add :reindex, :boolean, default: false, null: false
    end

    create(index(:pm_album, [:reindex, :id]))

    alter table(:pm_category) do
      add :reindex, :boolean, default: false, null: false
    end

    create(index(:pm_category, [:reindex, :id]))

    alter table(:pm_person) do
      add :reindex, :boolean, default: false, null: false
    end

    create(index(:pm_person, [:reindex, :id]))

    alter table(:pm_place) do
      add :reindex, :boolean, default: false, null: false
    end

    create(index(:pm_place, [:reindex, :id]))
  end
end
