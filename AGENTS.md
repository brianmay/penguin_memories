# AGENTS.md — penguin_memories

Elixir/Phoenix LiveView photo management application. PostgreSQL backend with
PostGIS. Image/video processing via ImageMagick, ffmpeg, and exiftool.

---

## Build & Setup

```bash
mix deps.get                  # fetch Hex dependencies
mix setup                     # deps.get + ecto.setup + npm install (full setup)
mix ecto.setup                # create DB + migrate + seed
mix ecto.reset                # drop + setup (destructive)
mix phx.server                # start dev server
```

Aliases defined in `mix.exs`:
- `mix setup` → `deps.get`, `ecto.setup`, `cmd npm install --prefix assets`
- `mix ecto.setup` → `ecto.create`, `ecto.migrate`, `run priv/repo/seeds.exs`
- `mix test` → `ecto.create --quiet`, `ecto.migrate --quiet`, then run tests

---

## Test Commands

```bash
mix test                                         # run all tests (default)
mix test test/penguin_memories/media_test.exs    # run a single test file
mix test test/penguin_memories/media_test.exs:42 # run test at specific line number
mix test --trace                                 # verbose output (prints test names)
mix test --only slow                             # run only :slow-tagged tests
mix test --include slow                          # include :slow tests alongside defaults
mix test --exclude slow                          # explicitly exclude :slow tests
```

**Default exclusions:** `test_helper.exs` excludes `:broken` and `:slow` tagged
tests by default. Use `--only slow` or `--include slow` to run them.

**Database isolation:** Tests use Ecto SQL sandbox in `:manual` mode.
`DataCase` and `ConnCase` in `test/support/` handle sandbox setup automatically.

**Mocking:** Use `Mox` for behaviour-based mocks. A mock for
`PenguinMemories.Database.Impl.Index.API` is pre-configured in `test_helper.exs`.

---

## Lint & Format Commands

```bash
mix format                    # format all Elixir files (always run before committing)
mix format --check-formatted  # dry-run check (used in CI)
mix credo                     # static analysis (Credo)
mix dialyzer                  # type checking (Dialyzer — slow, builds PLTs)
```

**Compiler warnings are errors** (`warnings_as_errors: true` in `mix.exs`).
The build will fail on any warning. CI enforces `mix format --check-formatted`,
`mix credo`, and `mix dialyzer`.

---

## Frontend Assets

```bash
cd assets && npm install         # install JS dependencies
cd assets && npm run deploy      # production build (webpack)
cd assets && npm run watch       # dev watch (usually run automatically by Phoenix)
```

Stack: Webpack 5, Bootstrap 5, SCSS. Assets are in `assets/`; compiled output
goes to `priv/static/`. The `assets/` directory is excluded from Prettier
(see `.prettierignore`).

---

## System Dependencies (required at runtime)

- `graphicsmagick-imagemagick-compat` — image resizing/conversion
- `libimage-exiftool-perl` — EXIF metadata extraction
- `ffmpeg` — video transcoding
- `exiftran` — lossless JPEG rotation
- `libraw-bin` — RAW camera file processing (`dcraw_emu`)

---

## Code Style

### Formatting

- Run `mix format` before every commit. CI rejects unformatted code.
- Config: `.formatter.exs` — imports rules from `:ecto` and `:phoenix`, uses
  `Phoenix.LiveView.HTMLFormatter` for `.html.heex` files.
- **Max line length: 120** characters (Credo enforces this).

### Module & File Structure

- One module per file; file name matches the last module segment in `snake_case`.
  - `PenguinMemories.Photos.Photo` → `lib/penguin_memories/photos/photo.ex`
- Business logic: `lib/penguin_memories/` — `PenguinMemories.*` namespace.
- Web layer: `lib/penguin_memories_web/` — `PenguinMemoriesWeb.*` namespace.
- Tests mirror `lib/` structure under `test/`.
  - `lib/penguin_memories/media.ex` → `test/penguin_memories/media_test.exs`

### Imports & Aliases

Order within a module body:
1. `use` statements
2. `alias` statements (alphabetically sorted — enforced by Credo)
3. `import` statements
4. `require` statements

```elixir
defmodule PenguinMemories.Example do
  use Ecto.Schema

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Photos.Photo

  import Ecto.Changeset
  import Ecto.Query
end
```

- Use full module paths in aliases; Elixir has no relative imports.
- Alias even single-use nested modules (Credo enforces alias usage for deeply
  nested modules).
- Use `import` sparingly — only for DSL-like modules (`Ecto.Changeset`,
  `Ecto.Query`).

### Naming Conventions

| Entity | Convention | Example |
|---|---|---|
| Modules | `PascalCase` | `PenguinMemories.Media` |
| Files | `snake_case.ex` | `media.ex` |
| Functions | `snake_case` | `get_media/2` |
| Boolean functions | `is_X` style | `is_image/1`, `is_valid/1` |
| Variables | `snake_case` | `photo_dir`, `size_key` |
| Unused vars | prefix `_` | `_params`, `_session` |
| Atoms/keys | `:snake_case` | `:original`, `:thumb` |
| Test modules | `ModuleNameTest` | `PenguinMemories.MediaTest` |

**Note:** `is_X` naming for boolean predicates is explicitly allowed —
`Credo.Check.Readability.PredicateFunctionNames` is disabled in `.credo.exs`.

### Typespecs

Every public and private function must have a `@spec`. Every struct must have
a `@type t :: %__MODULE__{...}` definition.

```elixir
@type t :: %__MODULE__{
        type: String.t(),
        path: String.t()
      }

@spec is_image(t()) :: boolean()
def is_image(%__MODULE__{type: type}), do: guard_is_image(type)

@spec get_media(String.t(), String.t() | nil) :: {:ok, t()} | {:error, String.t()}
def get_media(path, format \\ nil) do
  # ...
end
```

### Structs

Always use `@enforce_keys` to prevent partial initialization:

```elixir
@enforce_keys [:type, :subtype, :path]
defstruct [:type, :subtype, :path, optional_field: nil]
```

### Behaviour Implementations

Always annotate callback implementations with `@impl`:

```elixir
@impl API
def get_object(id, type), do: # ...

@impl true
def handle_event("save", params, socket), do: # ...
```

### Error Handling

**Primary pattern:** `{:ok, value} | {:error, String.t()}` tagged tuples.

Chain with `with`:
```elixir
with :ok <- File.mkdir_p(dest_dir),
     {:ok, _} <- File.copy(src, dest),
     :ok <- File.chmod(dest, 0o644) do
  get_media(dest, format)
else
  {:error, reason} ->
    {:error, "copy failed: #{inspect(reason)}"}
end
```

Use `cond` for multi-branch boolean logic:
```elixir
cond do
  not is_valid(media) -> {:error, "invalid media"}
  not File.exists?(media.path) -> {:error, "file not found"}
  true -> {:ok, media}
end
```

Use bang variants (`Repo.insert!`, `File.stat!`) only for operations that
should raise on failure (Erlang "let it crash" — use when failure is truly
unexpected and unrecoverable).

Use Ecto changesets for validation errors; return `{:error, changeset}` and
let callers inspect `changeset.errors`.

### Tests

- Use `describe "function_name/arity"` blocks with `test "description"` inside.
- Use `DataCase` for tests that touch the database.
- Use `ConnCase` for HTTP/LiveView tests.
- Tag slow tests with `@tag :slow`, broken tests with `@tag :broken`.
- Use `Mox` for mocking — stub behaviours, not modules directly.
- Pure unit tests can use `async: true`; DB tests typically cannot.

```elixir
defmodule PenguinMemories.MediaTest do
  use PenguinMemories.DataCase

  describe "get_media/2" do
    test "returns ok for valid image path" do
      assert {:ok, media} = Media.get_media("/path/to/file.jpg")
      assert media.type == "image"
    end

    @tag :slow
    test "processes large RAW files" do
      # ...
    end
  end
end
```

---

## Commit Messages

Conventional Commits enforced by `.commitlintrc.yaml`.

Format: `type(scope): description`

Allowed types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`,
`refactor`, `revert`, `style`, `test`

Examples:
- `feat(photos): add support for HEIC format`
- `fix(upload): handle missing exiftool gracefully`
- `test(media): add slow test for RAW processing`

---

## Key Project Conventions Summary

- **Format before commit:** `mix format`
- **Typespecs on every function:** public and private
- **`@enforce_keys` on every struct**
- **`@impl` on every behaviour callback**
- **Aliases sorted alphabetically** (Credo enforces)
- **Error tuples:** `{:ok, value}` / `{:error, String.t()}`; chain with `with`
- **`is_X` predicate naming** is the project norm (non-standard but explicit)
- **Tests mirror `lib/` structure**; tag slow/broken tests appropriately
- **Mox for mocks** — behaviour-based, not ad-hoc
