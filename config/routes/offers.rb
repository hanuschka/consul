resources :offers, path: "angebote", only: [:index, :show, :new, :create, :edit, :update] do
  member do
    patch :deactivate
    patch :activate
  end
end
