defmodule PenguinMemories.Repo do
  use Ecto.Repo,
    otp_app: :penguin_memories,
    adapter: Ecto.Adapters.Postgres

  use Paginator,
    include_total_count: true
end
