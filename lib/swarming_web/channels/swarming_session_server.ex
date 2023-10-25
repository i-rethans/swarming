defmodule SwarmingWeb.SwarmingSessionServer do
  use GenServer

  alias SwarmingWeb.Endpoint
  alias Swarming.Sessions.Session
  alias Swarming.Repo
  alias Swarming.Sessions.Serializer

  @tick_interval 250

  def start_link(%{session_id: _session_id} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(%{session_id: session_id} = _state) do
    # Schedule work to be performed on start
    state = %{session_id: session_id, extreme_values: [], group_direction: :right}

    state = schedule_tick(state)
    start_timer(session_id)

    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    # Do the desired work here
    # ...

    # Reschedule once more
    state = schedule_tick(state)

    {:noreply, state}
  end

  @impl true
  def handle_info(:quit, %{session_id: session_id, extreme_values: extreme_values} = state) do
    sum =
      extreme_values
      |> Enum.sum()

    average =
      sum / length(extreme_values)

    session =
      Session
      |> Repo.get!(session_id)
      |> Session.changeset(%{state: :finished, value: average})
      |> Repo.update!()

    Endpoint.broadcast(
      "session:#{session_id}",
      "stop",
      session |> Serializer.get_session_state()
    )

    {:stop, :normal, state}
  end

  defp start_timer(session_id) do
    session = Session |> Repo.get!(session_id)
    Process.send_after(self(), :quit, session.swarming_time)
  end

  defp schedule_tick(%{
         session_id: session_id,
         extreme_values: extreme_values,
         group_direction: group_direction
       }) do
    session = Session |> Repo.get!(session_id) |> Repo.preload(:participants)
    left = session.participants |> Enum.filter(fn p -> p.direction == :left end) |> length()
    right = session.participants |> Enum.filter(fn p -> p.direction == :right end) |> length()

    number_of_participants = session.participants |> length()

    delta =
      get_delta(left, right) *
        (number_of_participants / (number_of_participants + 1))

    value = (session.value + delta) |> check_lowerboud() |> check_upperbound()

    new_group_direction = get_group_direction(delta, group_direction)

    extreme_values =
      is_bound(new_group_direction, group_direction, session.swarming_time)
      |> update_extreme_values(extreme_values, value)

    Endpoint.broadcast(
      "session:#{session_id}",
      "value_update",
      session |> Serializer.get_session_state() |> Map.put(:value, value)
    )

    session
    |> Session.changeset(%{value: value, swarming_time: session.swarming_time - @tick_interval})
    |> Repo.update!()

    Process.send_after(self(), :tick, @tick_interval)

    %{
      session_id: session_id,
      extreme_values: extreme_values,
      group_direction: new_group_direction
    }
  end

  defp get_group_direction(delta, _group_direction) when delta > 0, do: :right
  defp get_group_direction(delta, _group_direction) when delta < 0, do: :left
  defp get_group_direction(_delta, _group_direction), do: :neutral

  defp get_delta(left, right) when left == 0 and right == 0, do: 0
  defp get_delta(left, right), do: (right - left) / (right + left)

  defp is_bound(_, _, time) when time >= 25000, do: false
  defp is_bound(:neutral, _, _time), do: true
  defp is_bound(:right, :left, _time), do: true
  defp is_bound(:left, :right, _time), do: true
  defp is_bound(_new_group_direction, _current_group_direction, _time), do: false

  defp update_extreme_values(true, extreme_values, value) do
    extreme_values = [value | extreme_values |> Enum.take(16)]

    differences =
      Enum.reduce(extreme_values, {[], hd(extreme_values)}, fn x, {acc, previous_x} ->
        {[abs(x - previous_x) | acc], x}
      end)
      |> elem(0)

    check_convergence(differences) |> stop_if_converged()

    reset_extreme_values(differences) |> do_reset(extreme_values)
  end

  defp update_extreme_values(false, extreme_values, _value), do: extreme_values

  defp check_convergence(differences) when length(differences) >= 6 do
    within_one(differences) or all_zero(differences)
  end

  defp check_convergence(_extreme_values), do: false

  defp within_one(differences) do
    differences = Enum.take(differences, 6)

    Enum.all?(differences, fn x -> abs(x) <= 1 end) and
      not Enum.all?(differences, fn x -> abs(x) == 0 end)
  end

  defp all_zero(differences) when length(differences) == 16 do
    Enum.all?(differences, fn x -> abs(x) == 0 end)
  end

  defp all_zero(_differences), do: false

  defp reset_extreme_values([]), do: false
  defp reset_extreme_values(list) when length(list) == 1, do: false

  defp reset_extreme_values([head | tail]) do
    Enum.all?(tail, fn x -> abs(x) == 0 end) && head != 0
  end

  defp do_reset(true, _extreme_values), do: []
  defp do_reset(false, extreme_values), do: extreme_values

  defp stop_if_converged(true), do: Process.send(self(), :quit, [])
  defp stop_if_converged(false), do: nil

  defp check_upperbound(value) when value > 20, do: 20
  defp check_upperbound(value), do: value

  defp check_lowerboud(value) when value < 0, do: 0
  defp check_lowerboud(value), do: value
end
