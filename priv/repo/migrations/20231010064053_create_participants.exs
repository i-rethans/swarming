defmodule Swarming.Repo.Migrations.CreateParticipants do
  use Ecto.Migration

  def change do
    create table(:participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :direction, :string, null: false

      add :session_id, references(:sessions, on_delete: :delete_all, type: :binary_id),
        null: false

      timestamps()
    end

    create index(:participants, [:session_id])
  end
end
