defmodule SwarmingWeb.SessionChannel do
  use SwarmingWeb, :channel
  alias Swarming.Sessions.Session
  alias Swarming.Repo
  alias Swarming.Participants.Participant
  alias Swarming.Sessions.Serializer
  alias SwarmingWeb.SwarmingSession
  alias SwarmingWeb.SwarmingSessionServer
  alias SwarmingWeb.Endpoint

  @impl true
  @spec join(<<_::64, _::_*8>>, map, Phoenix.Socket.t()) :: {:ok, Phoenix.Socket.t()}
  def join("session:" <> session_id, %{"participant_id" => participant_id}, socket) do
    socket = socket |> assign(:session_id, session_id)

    Session
    |> Repo.get(session_id)
    |> Repo.preload(:participants)
    |> do_join(socket, participant_id)
  end

  defp do_join(nil, socket, participant_id) do
    session =
      %Session{}
      |> Session.create_changeset(%{
        id: socket.assigns.session_id,
        state: :started
      })
      |> Repo.insert!()

    %Participant{}
    |> Participant.changeset(%{
      id: participant_id,
      direction: :neutral,
      session_id: session.id,
      admin: false
    })
    |> Repo.insert!()
    |> broadcast_new_participant(session.id)

    attrs = %{
      participants: 1,
      question: nil
    }

    socket = socket |> assign(attrs)

    {:ok, socket}
  end

  defp do_join(session, socket, participant_id) do
    Participant
    |> Repo.get(participant_id)
    |> get_or_insert(participant_id, socket.assigns.session_id)

    attrs = %{
      participants: (session.participants |> length()) + 1,
      question: session.question
    }

    socket = socket |> assign(attrs)

    {:ok, socket}
  end

  defp get_or_insert(nil, participant_id, session_id) do
    %Participant{}
    |> Participant.changeset(%{
      id: participant_id,
      direction: :neutral,
      session_id: session_id,
      admin: false
    })
    |> Repo.insert!()
    |> broadcast_new_participant(session_id)
  end

  defp get_or_insert(participant, _participant_id, _session_id), do: participant

  defp broadcast_new_participant(participant, session_id) do
    Endpoint.broadcast("session:#{session_id}", "new_participant", %{
      participant_id: participant.id
    })
  end

  @impl true
  def handle_in("get_state", _payload, socket) do
    session =
      Session
      |> Repo.get!(socket.assigns.session_id)
      |> Serializer.get_session_state()

    {:reply, {:ok, session}, socket}
  end

  @impl true
  def handle_in(
        "set_question",
        payload,
        socket
      ) do
    Session
    |> Repo.get!(socket.assigns.session_id)
    |> check_question()
    |> set_question_reply(payload, socket)
  end

  defp check_question(%Session{question: nil} = session), do: session

  defp check_question(_session), do: nil

  defp set_question_reply(nil, _payload, socket) do
    {:reply, {:error, "question already set"}, socket}
  end

  defp set_question_reply(
         session,
         %{"question" => question, "participant_id" => participant_id} = _payload,
         socket
       ) do
    session =
      session
      |> Session.changeset(%{question: question})
      |> Repo.update!()
      |> Serializer.get_session_state()

    Participant
    |> Repo.get!(participant_id)
    |> Participant.changeset(%{admin: true})
    |> Repo.update!()

    {:reply, {:ok, session}, socket}
  end

  @impl true
  def handle_in(
        "change_direction",
        %{"direction" => direction, "participant_id" => participant_id},
        socket
      ) do
    IO.puts("changeDirection")

    Participant
    |> Repo.get!(participant_id)
    |> Participant.changeset(%{direction: direction |> String.to_atom()})
    |> Repo.update!()

    {:noreply, socket}
  end

  @impl true
  def handle_in("start", _payload, socket) do
    session =
      Session
      |> Repo.get!(socket.assigns.session_id)

    session
    |> Session.changeset(%{state: :swarming})
    |> Repo.update!()

    Endpoint.broadcast(
      "session:#{session.id}",
      "started",
      session |> Serializer.get_session_state()
    )

    # %{session_id: socket.assigns.session_id}
    # |> SwarmingSession.new()
    # |> Oban.insert()
    # |> IO.inspect()

    GenServer.start_link(SwarmingSessionServer, %{session_id: socket.assigns.session_id})

    {:noreply, socket}
  end
end
