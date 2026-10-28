lib = Rails.root.join("lib")

Rails.autoloaders.main.ignore(
  lib.join("assets"),
  lib.join("capistrano"),
  lib.join("middleware"),
  lib.join("omniauth_wordpress.rb"),
  lib.join("scripts"),
  lib.join("tasks")
)
