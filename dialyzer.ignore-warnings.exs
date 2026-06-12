[
  {"lib/penguin_memories/database/path_compute.ex",
   "The created anonymous function has no local return."},
  {"lib/penguin_memories/photos/album_path.ex", "Function new_path/2 has no local return."},
  {"lib/penguin_memories/photos/album_path.ex", "Function new_path/3 has no local return."},
  {"lib/penguin_memories/photos/album_path.ex", "The function call changeset will not succeed."},
  # Same root cause as the new_path entries above: dialyzer thinks the
  # changeset call cannot succeed, so the @spec no longer matches.
  {"lib/penguin_memories/photos/album_path.ex", :invalid_contract},
  # False positives on MapSet/Ecto.Multi opaque internals with the
  # OTP 29 / Elixir 1.20 PLT.
  {"lib/penguin_memories/database/impl/backend/album.ex", :call_without_opaque},
  {"lib/penguin_memories/database/index.ex", :call_without_opaque},
  {"lib/penguin_memories/database/path_compute.ex", :call_without_opaque},
  {"lib/penguin_memories/database/query.ex", :call_without_opaque},
  {"lib/penguin_memories/upload.ex", :call_without_opaque}
]
