set :branch, ENV["branch"]

server deploysecret(:server), user: deploysecret(:user), roles: %w[web app db importer cron background]

set :default_env, {
  "XDG_RUNTIME_DIR" => "/run/user/1001",
  "DBUS_SESSION_BUS_ADDRESS" => "unix:path=/run/user/1001/bus"
}
