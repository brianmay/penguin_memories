# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :penguin_memories,
  ecto_repos: [PenguinMemories.Repo],
  # image_dir: "/home/brian/photos/images",
  # image_url: "https://photos.linuxpenguins.xyz/images",
  image_dir: "/tmp/images",
  image_url: "/images",
  cameras: %{
    "Canon EOS R5" => "10:59:36",
    "Canon EOS 350D DIGITAL" => "11:00:00"
  },
  sizes: %{
    "thumb" => %{max_width: 120, max_height: 90},
    "mid" => %{max_width: 480, max_height: 360},
    "large" => %{max_width: 1920, max_height: 1440}
  },
  formats: ["image/jpeg", "image/gif", "video/mp4", "video/ogg", "video/webm"],
  index_api: PenguinMemories.Database.Impl.Index.Generic

config :penguin_memories, PenguinMemories.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# Configures the endpoint
config :penguin_memories, PenguinMemoriesWeb.Endpoint,
  http: [:inet6, port: String.to_integer(System.get_env("PORT") || "4000")],
  url: [host: "localhost"],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  render_errors: [view: PenguinMemoriesWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: PenguinMemories.PubSub,
  live_view: [signing_salt: System.get_env("SIGNING_SALT")]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :penguin_memories, PenguinMemories.Accounts.Guardian,
  issuer: "penguin_memories",
  secret_key: System.get_env("GUARDIAN_SECRET")

config :mime, :types, %{"image/cr2" => ["cr2"]}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
