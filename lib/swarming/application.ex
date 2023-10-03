defmodule Swarming.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      SwarmingWeb.Telemetry,
      # Start the Ecto repository
      Swarming.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Swarming.PubSub},
      # Start Finch
      {Finch, name: Swarming.Finch},
      # Start the Endpoint (http/https)
      SwarmingWeb.Endpoint
      # Start a worker by calling: Swarming.Worker.start_link(arg)
      # {Swarming.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Swarming.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SwarmingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
