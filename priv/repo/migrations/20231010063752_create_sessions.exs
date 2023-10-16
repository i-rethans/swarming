defmodule Swarming.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :state, :string, null: false
      add :question, :string, null: true
      add :value, :float, null: false
      add :swarming_time, :integer, null: false

      timestamps()
    end
  end
end
