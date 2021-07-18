defmodule PenguinMemoriesWeb.Plug.Auth do
  @moduledoc "Guardian authentication pipeline"
  use Guardian.Plug.Pipeline,
    otp_app: :penguin_memories,
    error_handler: PenguinMemories.Accounts.ErrorHandler,
    module: PenguinMemories.Accounts.Guardian

  # If there is a session token, restrict it to an access token and validate it
  plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}, halt: false
  # If there is an authorization header, restrict it to an access token and validate it
  plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  # Load the user if either of the verifications worked
  plug Guardian.Plug.LoadResource, allow_blank: true
end
