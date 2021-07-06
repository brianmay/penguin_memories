defmodule PenguinMemories.Repo.Migrations.AddAlbumSortName do
  use Ecto.Migration

  def up do
    alter table(:pm_album) do
      add :sort_name, :string, null: true
    end
  end

  def down do
    alter table(:pm_album) do
      remove :sort_name, :string, null: true
    end
  end
end
