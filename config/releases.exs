import Config

port = String.to_integer(System.get_env("PORT") || "4000")

config :penguin_memories,
  image_dir: System.get_env("IMAGE_DIR")

config :penguin_memories, PenguinMemories.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :penguin_memories, PenguinMemoriesWeb.Endpoint,
  http: [:inet6, port: port],
  url: [host: System.get_env("HTTP_HOST"), port: port],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  live_view: [signing_salt: System.get_env("SIGNING_SALT")]

config :penguin_memories, PenguinMemories.Accounts.Guardian,
  issuer: "penguin_memories",
  secret_key: System.get_env("GUARDIAN_SECRET")

config :libcluster,
  topologies: [
    k8s: [
      strategy: Elixir.Cluster.Strategy.Kubernetes,
      config: [
        mode: :dns,
        kubernetes_node_basename: "penguin_memories",
        kubernetes_selector: System.get_env("KUBERNETES_SELECTOR"),
        kubernetes_namespace: System.get_env("NAMESPACE"),
        polling_interval: 10_000
      ]
    ]
  ]
