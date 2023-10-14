defmodule Swarming.Participants.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "participants" do
    field :direction, Ecto.Enum, values: ~w(left right neutral)a
    belongs_to :session, Swarming.Sessions.Session

    timestamps()
  end

  @doc false
  def changeset(session, attrs \\ %{}) do
    session
    |> cast(attrs, [:id, :direction, :session_id])
    |> validate_required([:id, :direction, :session_id])
  end
end
