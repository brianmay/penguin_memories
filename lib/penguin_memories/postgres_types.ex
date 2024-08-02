Postgrex.Types.define(
  PenguinMemories.PostgresTypes,
  [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(),
  json: Jason
)
