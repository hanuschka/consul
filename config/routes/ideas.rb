resources :ideas, except: [:edit, :update, :destroy] do
  member do
    get :json_data
  end

  collection do
    get :suggest
  end
end
