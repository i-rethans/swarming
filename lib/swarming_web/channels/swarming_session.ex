defmodule SwarmingWeb.SwarmingSession do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias SwarmingWeb.Endpoint
  alias Swarming.Sessions.Session
  alias Swarming.Repo

  @tick_interval 250

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id}}) do
    schedule_tick(session_id)
    :ok
  end

  defp schedule_tick(session_id) do
    session =
      Session
      |> Repo.get!(session_id)
      |> Repo.preload(:participants)
      |> IO.inspect(label: "session")

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
      |> IO.inspect(label: " + delta")
      |> check_lowerboud()
      |> check_upperbound()
      |> IO.inspect(label: "value")

    Endpoint.broadcast("session:#{session_id}", "value_update", %{
      value: value,
      swarming_time: session.swarming_time - @tick_interval
    })

    session
    |> Session.changeset(%{value: value, swarming_time: session.swarming_time - @tick_interval})
    |> IO.inspect(label: "updated session")
    |> Repo.update!()

    :timer.sleep(@tick_interval)

    case session.swarming_time - @tick_interval do
      0 -> :ok
      _ -> schedule_tick(session_id)
    end
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
