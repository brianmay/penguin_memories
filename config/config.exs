# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :penguin_memories,
  ecto_repos: [PenguinMemories.Repo]

# Configures the endpoint
config :penguin_memories, PenguinMemoriesWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "erwBSwyRN1KZpNCE22IakZD6QRE66R5NDRrcbVDObAalIRzNAf7net4aOwmFg7wJ",
  render_errors: [view: PenguinMemoriesWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: PenguinMemories.PubSub,
  live_view: [signing_salt: "TjHD3iSQ"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
