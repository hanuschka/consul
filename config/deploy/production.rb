set :branch, ENV["branch"]

server deploysecret(:server1), user: deploysecret(:user), roles: %w[web app db importer cron background]
#server deploysecret(:server2), user: deploysecret(:user), roles: %w(web app db importer cron background)
#server deploysecret(:server3), user: deploysecret(:user), roles: %w(web app db importer)
#server deploysecret(:server4), user: deploysecret(:user), roles: %w(web app db importer)

set :default_env, {
  "XDG_RUNTIME_DIR" => "/run/user/1001",
  "DBUS_SESSION_BUS_ADDRESS" => "unix:path=/run/user/1001/bus"
}
