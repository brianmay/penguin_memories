defmodule PenguinMemoriesWeb.LiveRequest do
  @moduledoc """
  Shared stuff for all live views.
  """
  alias Elixir.Phoenix.LiveView

  alias PenguinMemories.Accounts

  @type t :: %__MODULE__{
          url: URI.t(),
          host_url: URI.t(),
          user: Accounts.User.t(),
          big_id: String.t() | nil,
          force_reload: boolean()
        }

  @enforce_keys [
    :url,
    :host_url,
    :user,
    :big_id,
    :force_reload
  ]

  defstruct url: nil,
            host_url: nil,
            user: nil,
            big_id: nil,
            force_reload: false

  @spec apply_common(LiveView.Socket.t(), t()) :: LiveView.Socket.t()
  def apply_common(%LiveView.Socket{} = socket, %__MODULE__{} = request) do
    %LiveView.Socket{socket | host_uri: request.host_url}
    |> LiveView.assign(common: request)
  end
end
