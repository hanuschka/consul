module ApiAccessRequirements
  ADMIN_REQUIRED = "\n\n*Authorization: Requires `admin` access level. Requests with `public_data` access level will receive `403 Forbidden`.*".freeze

  GET_READ_ONLY = "\n\n*Authorization: Available to both `admin` and `public_data` access levels.*".freeze

  CONFIGURATION_REQUIRED = "\n\n*Authorization: Requires an `admin` client with the instance " \
    "configuration access right (\"Zugriff auf Instanz-Konfiguration\" in /adm). Other clients, " \
    "including internal ones, receive `403 Forbidden`. Every change is recorded in the audit " \
    "trail with the client, the time, and the old and new value.*".freeze
end
