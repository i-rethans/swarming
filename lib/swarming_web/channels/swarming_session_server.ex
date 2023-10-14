defmodule SwarmingWeb.SwarmingSessionServer do
  use GenServer

  alias SwarmingWeb.Endpoint
  alias Swarming.Sessions.Session
  alias Swarming.Repo
  alias Swarming.Sessions.Serializer

  def start_link(%{session_id: _session_id} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(%{session_id: session_id} = _state) do
    # Schedule work to be performed on start
    schedule_tick(session_id)

    state = %{session_id: session_id, count: 1}

    {:ok, state}
  end

  @impl true
  def handle_info(:tick, %{count: count} = state) when count == 30 do
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, %{session_id: session_id} = state) do
    # Do the desired work here
    # ...

    # Reschedule once more
    schedule_tick(session_id)

    state = %{session_id: session_id, count: state.count + 1}

    {:noreply, state}
  end

  defp schedule_tick(session_id) do
    session = Session |> Repo.get!(session_id) |> Repo.preload(:participants)
    left = session.participants |> Enum.filter(fn p -> p.direction == :left end) |> length()
    right = session.participants |> Enum.filter(fn p -> p.direction == :right end) |> length()

    delta = get_delta(left, right)
    value = (session.value + delta) |> check_lowerboud() |> check_upperbound()

    Endpoint.broadcast(
      "session:#{session_id}",
      "value_update",
      session |> Serializer.get_session_state()
    )

    session
    |> Session.changeset(%{value: value})
    |> Repo.update!()

    Process.send_after(self(), :tick, 1000)
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
