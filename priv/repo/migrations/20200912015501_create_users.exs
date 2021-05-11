defmodule PenguinMemories.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :text, null: false
      add :name, :text, null: false
      add :password_hash, :text, null: false
      add :is_admin, :boolean, default: false, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:users, [:username]))
  end
end
