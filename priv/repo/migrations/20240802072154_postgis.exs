defmodule PenguinMemories.Repo.Migrations.Postgis do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS postgis")
    execute("SELECT AddGeometryColumn ('pm_photo','point',4326,'POINT',2);")
    execute("CREATE INDEX pm_point_index ON pm_photo USING GIST (point);")
  end

  def down do
    execute("DROP INDEX pm_point_index;")
    execute("ALTER TABLE pm_photo DROP COLUMN point;")
    execute("DROP EXTENSION IF EXISTS postgis")
  end
end
