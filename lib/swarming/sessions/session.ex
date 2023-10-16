defmodule Swarming.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "sessions" do
    field :state, Ecto.Enum, values: ~w(started swarming finished)a
    field :question, :string
    field :value, :float
    field :swarming_time, :integer

    has_many :participants, Swarming.Participants.Participant

    timestamps()
  end

  @doc false
  def create_changeset(session, attrs \\ %{}) do
    session
    |> cast(attrs, [:id, :state, :question, :value, :swarming_time])
    |> validate_required([:id, :state])
    |> put_change(:value, 0.0)
    |> put_change(:swarming_time, 30000)
  end

  def changeset(session, attrs \\ %{}) do
    session
    |> cast(attrs, [:id, :state, :question, :value, :swarming_time])
    |> validate_required([:id, :state])
  end
end
