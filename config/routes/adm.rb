namespace :adm do
  root to: "dashboard#show"

  resources :projekts, only: [:index, :show]
end
