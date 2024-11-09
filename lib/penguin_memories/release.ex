defmodule PenguinMemories.Release do
  @app :penguin_memories

  import Ecto.Query
  alias PenguinMemories.Repo

  def migrate do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    for r <- repos(), r == repo do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    end
  end

  def seconds_since_last_migration do
    Repo.one(
      from m in "schema_migrations",
        select: fragment("EXTRACT(EPOCH FROM age(NOW(), ?::timestamp))::BIGINT", m.inserted_at),
        order_by: [desc: m.inserted_at],
        limit: 1
    )
  end

  def health_check do
    repos = Application.fetch_env!(@app, :ecto_repos)

    migrations =
      repos
      |> Enum.map(&Ecto.Migrator.migrations/1)
      |> List.flatten()
      |> Enum.filter(fn
        {:up, _, _} -> false
        {_, _, _} -> true
      end)

    migrations =
      if Enum.empty?(migrations) do
        :ok
      else
        {:error, "Migrations pending: #{inspect(migrations)}"}
      end

    database =
      Enum.reduce_while(repos, :ok, fn item, _acc ->
        case Ecto.Adapters.SQL.query(item, "SELECT 1") do
          {:ok, %{num_rows: 1, rows: [[1]]}} ->
            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, inspect(reason)}}
        end
      end)

    case {migrations, database} do
      {:ok, :ok} -> :ok
      {{:error, reason}, _} -> {:error, reason}
      {_, {:error, reason}} -> {:error, reason}
    end
  end

  defp repos do
    Application.ensure_all_started(:ssl)
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end
end
