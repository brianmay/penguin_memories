# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :penguin_memories,
  build_date: System.get_env("BUILD_DATE"),
  vcs_ref: System.get_env("VCS_REF"),
  ecto_repos: [PenguinMemories.Repo],
  image_dir: System.get_env("IMAGE_DIR"),
  image_url: "/images",
  cameras: %{
    "Canon EOS R5" => {"Etc/UTC", "10:59:36"},
    "Canon EOS 350D DIGITAL" => {"Etc/UTC", "11:00:00"},
    "Canon EOS 5D Mark III" => {"Etc/UTC", "09:59:28"},
    "GT-I9305T" => {"Australia/Victoria", "00:00:00"},
    "SM-N976B" => {"Australia/Victoria", "00:00:00"},
    "SM-N986B" => {"Australia/Victoria", "00:00:00"},
    "Pixel XL" => {"Australia/Victoria", "00:00:00"}
  },
  sizes: %{
    "thumb" => %{max_width: 120, max_height: 90},
    "mid" => %{max_width: 480, max_height: 360},
    "large" => %{max_width: 1920, max_height: 1440}
  },
  formats: ["image/jpeg", "video/mp4", "video/webm"],
  index_api: PenguinMemories.Database.Impl.Index.Generic,
  oidc: %{
    discovery_document_uri: System.get_env("OIDC_DISCOVERY_URL"),
    client_id: System.get_env("OIDC_CLIENT_ID"),
    client_secret: System.get_env("OIDC_CLIENT_SECRET"),
    scope: System.get_env("OIDC_AUTH_SCOPE")
  }

config :penguin_memories, PenguinMemories.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# Configures the endpoint
default_port = if Mix.env() == :test, do: "4002", else: "4000"
port = String.to_integer(System.get_env("PORT") || default_port)
http_url = System.get_env("HTTP_URL") || "http://localhost:{port}"
http_uri = URI.parse(http_url)

config :penguin_memories, PenguinMemoriesWeb.Endpoint,
  http: [
    :inet6,
    port: port,
    protocol_options: [max_header_value_length: 8096]
  ],
  url: [scheme: http_uri.scheme, host: http_uri.host, port: http_uri.port],
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

config :libcluster,
  topologies: []

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :plugoid,
  auth_cookie_store: Plug.Session.COOKIE,
  auth_cookie_store_opts: [
    signing_salt: System.get_env("SIGNING_SALT")
  ],
  state_cookie_opts: [
    extra: "SameSite=None Secure"
  ],
  state_cookie_store_opts: [
    signing_salt: System.get_env("SIGNING_SALT")
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
