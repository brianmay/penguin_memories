# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :penguin_memories,
  ecto_repos: [PenguinMemories.Repo],
  image_url: "/images",
  cameras: %{
    "Canon EOS R5" => {"Australia/Victoria", "00:00:00"},
    "Canon EOS 350D DIGITAL" => {"Etc/UTC", "11:00:00"},
    "Canon EOS 5D Mark III" => {"Etc/UTC", "09:59:28"},
    "GT-I9305T" => {"Australia/Victoria", "00:00:00"},
    "SM-N976B" => {"Australia/Victoria", "00:00:00"},
    "SM-N986B" => {"Australia/Victoria", "00:00:00"},
    "Pixel XL" => {"Australia/Victoria", "00:00:00"},
    "Pixel 6 Pro" => {"Australia/Victoria", "00:00:00"},
    "COOLPIX P950" => {"Australia/Victoria", "00:00:00"}
  },
  sizes: %{
    "thumb" => %{max_width: 120, max_height: 90},
    "mid" => %{max_width: 480, max_height: 360},
    "large" => %{max_width: 1920, max_height: 1440}
  },
  formats: ["image/jpeg", "video/mp4", "video/webm"],
  index_api: PenguinMemories.Database.Impl.Index.Generic

config :penguin_memories, PenguinMemories.Repo,
  types: PenguinMemories.PostgresTypes

config :penguin_memories, PenguinMemoriesWeb.Endpoint,
  render_errors: [view: PenguinMemoriesWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: PenguinMemories.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :penguin_memories, PenguinMemories.Accounts.Guardian,
  issuer: "penguin_memories"

config :mime, :types, %{
  "image/cr2" => ["cr2"],
  "image/cr3" => ["cr3"]
}

config :libcluster,
  topologies: []

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :plugoid,
  auth_cookie_store: Plug.Session.COOKIE,
  auth_cookie_opts: [
    secure: true,
    extra: "SameSite=Lax"
  ],
  state_cookie_opts: [
    secure: true,
    extra: "SameSite=None"
  ]

config :elixir, :time_zone_database, Tz.TimeZoneDatabase
config :tzdata, :autoupdate, :disabled

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
