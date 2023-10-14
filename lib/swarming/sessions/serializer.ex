defmodule Swarming.Sessions.Serializer do
  import Ecto.Query
  alias Swarming.Sessions.Session
  alias Swarming.Repo

  def get_session_state(%Session{id: id}) do
    Session
    |> where([s], s.id == ^id)
    |> Repo.one()
    |> Repo.preload([
      :participants
    ])
    |> serialize()
  end

  defp serialize(struct) do
    struct
    |> drop_unserializable()
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      acc |> Map.put(key, serialize_value(value))
    end)
  end

  defp serialize_value(value) when is_struct(value), do: value |> serialize()

  defp serialize_value(value) when is_list(value) do
    value |> Enum.map(fn item -> item |> serialize_value() end)
  end

  defp serialize_value(value), do: value

  defp drop_unserializable(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__, :inserted_at, :updated_at])
    |> Map.reject(fn
      {_, %Ecto.Association.NotLoaded{}} -> true
      _ -> false
    end)
  end
end
