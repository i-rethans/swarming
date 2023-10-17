defmodule SwarmingWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :swarming

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_swarming_key",
    signing_salt: "lS06O9f4",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  socket "/socket", SwarmingWeb.UserSocket,
    websocket: [
      timeout: 45_000,
      check_origin: {SwarmingWeb.Endpoint, :check_origin, []}
    ],
    longpoll: false

  def check_origin(uri) do
    [
      ~r{^http://.*/?$},
      ~r{^https://(www\.)?swarming-web\.firebaseapp\.com\/?$},
      ~r{^http://localhost:3000/?$}
    ]
    |> Enum.any?(fn regex -> Regex.match?(regex, uri |> URI.to_string()) end)
  end

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :swarming,
    gzip: false,
    only: SwarmingWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :swarming
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug SwarmingWeb.Router
end
