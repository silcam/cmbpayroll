Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  resources :children

  shallow do
    resources :employees do
      resources :transactions
      resources :children
    end
  end

  root "mock#home"

  # Session Controller
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  # Mock Controller
  get 'mock_employees', to: 'mock#employees'
  get 'transactions', to: 'mock#transactions'
  get 'hours/edit', to: 'mock#hours_edit'
  get 'reports', to: 'mock#reports'
end
