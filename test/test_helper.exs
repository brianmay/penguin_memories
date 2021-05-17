Mox.defmock(PenguinMemories.Database.APIMock, for: PenguinMemories.Database.API)
Application.put_env(:penguin_memories, :api, PenguinMemories.Database.APIMock)

ExUnit.start(exclude: [:broken, :slow])
Ecto.Adapters.SQL.Sandbox.mode(PenguinMemories.Repo, :manual)
