module ApiAccessRequirements
  ADMIN_REQUIRED = "\n\n*Authorization: Requires `admin` access level. Requests with `public_data` access level will receive `403 Forbidden`.*".freeze

  GET_READ_ONLY = "\n\n*Authorization: Available to both `admin` and `public_data` access levels.*".freeze
end
