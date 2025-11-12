post "/graphql", to: "graphql#execute"
get "/graphql", to: "graphql#execute"

if Rails.env.development?
  mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
end
