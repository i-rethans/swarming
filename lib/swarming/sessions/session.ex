defmodule Swarming.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "sessions" do
    field :state, Ecto.Enum, values: ~w(started swarming finished)a
    field :question, :string
    field :value, :float

    has_many :participants, Swarming.Participants.Participant

    timestamps()
  end

  @doc false
  def create_changeset(session, attrs \\ %{}) do
    session
    |> cast(attrs, [:id, :state, :question, :value])
    |> validate_required([:id, :state])
    |> put_change(:value, 0.0)
  end

  def changeset(session, attrs \\ %{}) do
    session
    |> cast(attrs, [:id, :state, :question, :value])
    |> validate_required([:id, :state])
  end
end
