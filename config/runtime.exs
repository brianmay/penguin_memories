import Config

config :penguin_memories,
  image_dir: System.get_env("IMAGE_DIR"),
  oidc: %{
    discovery_document_uri: System.get_env("OIDC_DISCOVERY_URL"),
    client_id: System.get_env("OIDC_CLIENT_ID"),
    client_secret: System.get_env("OIDC_CLIENT_SECRET"),
    scope: System.get_env("OIDC_AUTH_SCOPE")
  },
  private_locations:
    System.get_env("PRIVATE_LOCATIONS", "")
    |> String.split(";", trim: true)
    |> Enum.map(fn x ->
      [lng, lat, distance] = String.split(x, ",")
      {lng, ""} = Float.parse(lng)
      {lat, ""} = Float.parse(lat)
      {distance, ""} = Integer.parse(distance)
      %Geocalc.Shape.Circle{latitude: lat, longitude: lng, radius: distance}
    end)

config :penguin_memories, PenguinMemories.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

port = String.to_integer(System.get_env("PORT") || "4000")
http_url = System.get_env("HTTP_URL", "http://localhost:#{port}")
http_uri = URI.parse(http_url)

config :penguin_memories, PenguinMemoriesWeb.Endpoint,
  http: [
    :inet6,
    port: port,
    protocol_options: [max_header_value_length: 8096]
  ],
  url: [scheme: http_uri.scheme, host: http_uri.host, port: http_uri.port],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  live_view: [signing_salt: System.get_env("SIGNING_SALT")]

config :penguin_memories, PenguinMemories.Accounts.Guardian,
  issuer: "penguin_memories",
  secret_key: System.get_env("GUARDIAN_SECRET")

config :plugoid,
  auth_cookie_store_opts: [
    signing_salt: System.get_env("SIGNING_SALT")
  ],
  state_cookie_store_opts: [
    signing_salt: System.get_env("SIGNING_SALT")
  ]

config :os_mon,
  start_disksup: false

if config_env() == :test do
  config :penguin_memories,
    image_dir: "/tmp/images",
    sizes: %{
      "thumb" => %{max_width: 120, max_height: 90},
      "mid" => %{max_width: 480, max_height: 360},
      "large" => %{max_width: 1920, max_height: 1440}
    },
    formats: ["image/jpeg", "image/gif", "video/mp4", "video/ogg", "video/webm"],
    oidc: %{
      discovery_document_uri: "",
      client_id: "",
      client_secret: "",
      scope: ""
    }

  # Configure your database
  #
  # The MIX_TEST_PARTITION environment variable can be used
  # to provide built-in test partitioning in CI environment.
  # Run `mix help test` for more information.
  config :penguin_memories, PenguinMemories.Repo,
    url: System.get_env("DATABASE_URL_TEST"),
    pool: Ecto.Adapters.SQL.Sandbox

  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  config :penguin_memories, PenguinMemoriesWeb.Endpoint, server: false

  # Print only warnings and errors during test
  config :logger, level: :warning

  config :penguin_memories, PenguinMemories.Accounts.Guardian,
    issuer: "penguin_memories",
    secret_key: "/q7S9SP028A/BbWqkiisc5qZXbBWQFg8+GSTkflTAfRw/K9jCzJKWpSWvWUEoUU4"

  config :penguin_memories, PenguinMemoriesWeb.Endpoint,
    secret_key_base: "oOWDT+7p6JENufDeyMQFLqDMsj1bkVfQT4Navmr5qYem9crHED4jAMr0Stf4aRNt",
    live_view: [
      signing_salt: "6JsXtIwI2Wo64YdWdWIl1UY8fb1i1ggw"
    ]

  config :plugoid,
    auth_cookie_store_opts: [
      signing_salt: "/EeCfa85oE1mkAPMo2kPsT5zkCFPveHk"
    ],
    state_cookie_store_opts: [
      signing_salt: "/EeCfa85oE1mkAPMo2kPsT5zkCFPveHk"
    ]
end
