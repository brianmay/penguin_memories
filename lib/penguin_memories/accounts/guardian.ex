defmodule PenguinMemories.Accounts.Guardian do
  @moduledoc "Guardian hook functions"
  use Guardian, otp_app: :penguin_memories

  alias PenguinMemories.Accounts

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end
end
