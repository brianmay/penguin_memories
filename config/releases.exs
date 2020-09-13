import Config

port = String.to_integer(System.get_env("PORT") || "4000")

config :penguin_memories,
  config_file: System.get_env("PM_HELLO_CONFIG")

config :penguin_memories, PenguinMemories.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :penguin_memories, PenguinMemoriesWeb.Endpoint,
  http: [:inet6, port: port],
  url: [host: System.get_env("HOST"), port: port],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  live_view: [signing_salt: System.get_env("SIGNING_SALT")]

config :penguin_memories, PenguinMemories.Accounts.Guardian,
  issuer: "penguin_memories",
  secret_key: System.get_env("GUARDIAN_SECRET")
