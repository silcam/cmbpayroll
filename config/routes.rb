Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  shallow do
    resources :employees do
      resources :transactions
    end
  end

  root "mock#home"
  get 'mock_employees', to: 'mock#employees'
  get 'transactions', to: 'mock#transactions'
  get 'hours/edit', to: 'mock#hours_edit'
  get 'reports', to: 'mock#reports'
end
