resources :related_contents, only: [:create, :destroy] do
  member do
    put :score_positive
    put :score_negative
  end
end
