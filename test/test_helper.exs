Mox.defmock(PenguinMemories.Database.Impl.Index.Mock,
  for: PenguinMemories.Database.Impl.Index.API
)

Application.put_env(:penguin_memories, :index_api, PenguinMemories.Database.Impl.Index.Mock)

ExUnit.start(exclude: [:broken, :slow])
Ecto.Adapters.SQL.Sandbox.mode(PenguinMemories.Repo, :manual)
