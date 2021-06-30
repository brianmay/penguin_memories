defmodule PenguinMemories.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)

    children = [
      # Start the Ecto repository
      PenguinMemories.Repo,
      # Start the Telemetry supervisor
      PenguinMemoriesWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: PenguinMemories.PubSub, adapter: Phoenix.PubSub.PG2},
      # Start the Endpoint (http/https)
      PenguinMemoriesWeb.Endpoint,
      {Cluster.Supervisor, [topologies, [name: PenguinMemories.ClusterSupervisor]]}
      # Start a worker by calling: PenguinMemories.Worker.start_link(arg)
      # {PenguinMemories.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PenguinMemories.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PenguinMemoriesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
