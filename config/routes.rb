Rails.application.routes.draw do

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  root "home#home"

  resources :vacations, except: :show
  resources :bonuses
  resources :work_loans, only: [ :index, :new, :create, :destroy ]
  resources :departments
  resources :holidays, except: [:show, :new] do
    collection do
      post 'generate/:year', to: 'holidays#generate', as: :generate
    end
  end
  resources :standard_charge_notes, only: [:index, :create, :destroy]
  shallow do
    resources :employees do
      get 'search', on: :collection
      resources :children, except: [:show]
      resources :raises
      resources :loans, except: [:show] do
        resources :loan_payments, except: [:show, :index]
      end
      resources :bonuses, only: [ :index ] do
        collection do
          get 'list_possible', to: 'bonuses#index'
          patch 'unassign'
          patch 'assign'
        end
      end
      resources :charges, except: [:edit, :update, :show]
      resources :vacations, except: :show do
        get 'days_summary', on: :collection
      end
      resources :payslips, only: [ :index, :show ]
    end
  end

  resources :supervisors, except: [:show]

  resources 'payslips', only: [ :index, :show ]

  # Reports index
  get 'reports', to: 'reports#index'
  get 'report_display', to: 'reports#show'
  get 'reports/*report', to: 'home#home' # eliminate gem routes
  get 'multi/reports/*report', to: 'home#home' # eliminate gem routes

  # Payslips
  post 'payslips/process', to: 'payslips#process_employee', as: :payslip_process_employee
  post 'payslips/process_complete', to: 'payslips#process_employee_complete', as: :payslip_process_employee_complete
  post 'payslips/process_all', to: 'payslips#process_all_employees', as: :payslip_process_all
  post 'payslips/post_period', to: 'payslips#post_period', as: :payslip_post_period
  post 'payslips/unpost_period', to: 'payslips#unpost_period', as: :payslip_unpost_period

  # Work Hours
  get 'workhours', to: 'work_hours#index', as: :work_hours
  get 'employees/:employee_id/work_hours',      to: 'work_hours#index', as: :employee_work_hours
  get 'employees/:employee_id/work_hours/edit', to: 'work_hours#edit',  as: :edit_employee_work_hours
  post 'employees/:employee_id/work_hours',    to: 'work_hours#update', as: :update_employee_work_hours

  # Administration
  get 'admin/index'
  get 'admin/manage_variables'
  get 'admin/manage_wages'
  get 'admin/manage_wage_show'
  post 'admin/manage_wage_show', to: 'admin#manage_wage_update'

  resources :users, except: [ 'show' ]

  # Session Controller
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  # Mock Controller
  get 'mock', to: "mock#home"
  get 'mock_employees', to: 'mock#employees'
  get 'mock_vacation', to: 'mock#vacation'
  get 'charges', to: 'mock#charges'
  get 'hours/edit', to: 'mock#hours_edit'
end
