use Mix.Config

config :penguin_memories,
  image_dir: "/tmp/images",
  sizes: %{
    "thumb" => [
      %{max_width: 120, max_height: 90, format: "image/jpeg"},
      %{max_width: 120, max_height: 90, format: "image/gif"},
      %{max_width: 120, max_height: 90, format: "video/mp4"},
      %{max_width: 120, max_height: 90, format: "video/ogg"},
      %{max_width: 120, max_height: 90, format: "video/webm"}
    ],
    "mid" => [
      %{max_width: 480, format: "image/jpeg"},
      %{max_width: 480, format: "image/gif"},
      %{max_width: 480, format: "video/mp4"},
      %{max_width: 480, format: "video/ogg"},
      %{max_width: 480, format: "video/webm"}
    ],
    "large" => [
      %{max_width: 1920, format: "image/jpeg"},
      %{max_width: 1920, format: "image/gif"},
      %{max_width: 1920, format: "video/mp4"},
      %{max_width: 1920, format: "video/ogg"},
      %{max_width: 1920, format: "video/webm"}
    ]
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
config :penguin_memories, PenguinMemoriesWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :penguin_memories, PenguinMemories.Accounts.Guardian,
  issuer: "penguin_memories",
  secret_key: "/q7S9SP028A/BbWqkiisc5qZXbBWQFg8+GSTkflTAfRw/K9jCzJKWpSWvWUEoUU4"

config :penguin_memories, PenguinMemoriesWeb.Endpoint,
  secret_key_base: "oOWDT+7p6JENufDeyMQFLqDMsj1bkVfQT4Navmr5qYem9crHED4jAMr0Stf4aRNt",
  live_view: [
    signing_salt: "6JsXtIwI2Wo64YdWdWIl1UY8fb1i1ggw"
  ]
