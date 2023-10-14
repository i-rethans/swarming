defmodule SwarmingWeb.SwarmingSession do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias SwarmingWeb.Endpoint
  alias Swarming.Sessions.Session
  alias Swarming.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id}}) do
    schedule_tick(session_id, 0)
    :ok
  end

  defp schedule_tick(_session_id, count) when count == 20 do
    :ok
  end

  defp schedule_tick(session_id, count) do
    session = Session |> Repo.get!(session_id) |> Repo.preload(:participants)

    left =
      session.participants
      |> Enum.filter(fn p -> p.direction == :left end)
      |> length()
      |> IO.inspect(label: "left")

    right =
      session.participants
      |> Enum.filter(fn p -> p.direction == :right end)
      |> length()
      |> IO.inspect(label: "right")

    delta = get_delta(left, right) |> IO.inspect(label: "delta")

    value =
      (session.value + delta)
      |> check_lowerboud()
      |> check_upperbound()
      |> IO.inspect(label: "value")

    Endpoint.broadcast("session:#{session_id}", "value_update", %{value: value})

    session
    |> Session.changeset(%{value: value})
    |> Repo.update!()
    |> IO.inspect(label: "session")

    :timer.sleep(500)
    schedule_tick(session_id, count + 1)
  end

  def get_delta(left, right) when left == 0 and right == 0, do: 0
  def get_delta(left, right), do: (right - left) / (right + left)

  defp check_upperbound(value) when value > 20, do: 20
  defp check_upperbound(value), do: value

  defp check_lowerboud(value) when value < 0, do: 0
  defp check_lowerboud(value), do: value

  def handle_info(:quit, state) do
    {:stop, :normal, state}
  end
end
