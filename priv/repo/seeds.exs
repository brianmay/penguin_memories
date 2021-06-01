# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     PenguinMemories.Repo.insert!(%PenguinMemories.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

{:ok, _} =
  PenguinMemories.Accounts.create_user(%{
    is_admin: true,
    username: "test",
    password: "testtest",
    password_confirmation: "testtest",
    name: "Test User"
  })

PenguinMemories.Repo.insert!(%PenguinMemories.Photos.Album{
  name: "Uploads"
})

%PenguinMemories.Photos.FileOrder{size_key: "thumb", mime_type: "image/jpeg", order: 0}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "thumb", mime_type: "image/gif", order: 1}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "thumb", mime_type: "video/ogg", order: 2}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "thumb", mime_type: "video/webm", order: 3}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "thumb", mime_type: "video/mp4", order: 4}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "mid", mime_type: "image/jpeg", order: 0}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "mid", mime_type: "image/gif", order: 1}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "mid", mime_type: "video/ogg", order: 2}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "mid", mime_type: "video/webm", order: 3}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "mid", mime_type: "video/mp4", order: 4}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "large", mime_type: "image/jpeg", order: 0}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "large", mime_type: "image/gif", order: 1}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "large", mime_type: "video/ogg", order: 2}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "large", mime_type: "video/webm", order: 3}
|> PenguinMemories.Repo.insert!()

%PenguinMemories.Photos.FileOrder{size_key: "large", mime_type: "video/mp4", order: 4}
|> PenguinMemories.Repo.insert!()
