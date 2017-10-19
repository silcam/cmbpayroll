class AccessPolicy
  include AccessGranted::Policy

  def configure
    # Access Policy file for CMB EPS
    #
    # For more details on how to manage this file, check the README at
    #
    # https://github.com/chaps-io/access-granted/blob/master/README.md
    #
    # Remember, roles inherit from less important roles, so:
    # - :admin has permissions defined in :member, :guest and himself
    # - :member has permissions from :guest and himself
    # - :guest has only its own permissions since it's the first role.
    #
    #
    # BEGIN CMB EPS ROLES
    # ===================
    #
    # The most important role should be at the top.
    # In this case an administrator.
    role :admin, proc { |user| user.admin?} do
      # permissions go here

      # can do everything.
      can :read, AdminController # see admin pages

      can :create, Employee
      can :read, Employee
      can :update, Employee
      can :destroy, Employee

      can :read, Wage
      can :update, Wage

      can :create, Bonus
      can :read, Bonus
      can :update, Bonus
      can :destroy, Bonus

      can :create, Charge
      can :read, Charge
      can :update, Charge
      can :destroy, Charge

      can :create, Department
      can :read, Department
      can :update, Department
      can :destroy, Department

      can :create, Loan
      can :read, Loan
      can :update, Loan
      can :destroy, Loan

      can :create, LoanPayment
      can :read, LoanPayment
      can :update, LoanPayment
      can :destroy, LoanPayment

      can :create, StandardChargeNote
      can :read, StandardChargeNote
      can :update, StandardChargeNote
      can :destroy, StandardChargeNote
    end

    # More privileged role, in this case supervisors
    # are able to see employees that they supervise
    # and perform limited administration on these
    # employees.
    role :supervisor, proc { |user| user.supervisor?} do
      # permissions go here

      # TODO, multi-level supervisors
      can :read, Employee do |employee, user|
        # can read if this user is the employee's supervisor
        employee.supervisor.person.id == user.person.id
      end

      # TODO, multi-level supervisors
      can :update, Employee do |employee, user|
        # can update if user is employee's supervisor
        employee.supervisor.person.id == user.person.id
      end

      can :read, Charge do |charge, user|
        # can read if charge is for reporting employee
        charge.employee.supervisor.person.id == user.person.id
      end

      can :read, Loan do |loan, user|
        # can read if loan is for reporting employee
        loan.employee.supervisor.person.id == user.person.id
      end

      can :read, LoanPayment do |loan_payment, user|
        # can read if loan_payment is for reporting employee
        loan_payment.loan.employee.supervisor.person.id == user.person.id
      end
    end

    # An employee with user role can perform limited
    # operations on herself (read, mostly).
    role :self, proc { |user| user.user?} do
      # permissions go here

      can :read, Employee do |employee, user|
        # can read if looking at self
        employee.person.id == user.person.id
      end

      can :read, Charge do |charge, user|
        # can read if looking at self
        charge.employee.person.id == user.person.id
      end

      can :read, Loan do |loan, user|
        # can read if looking at self
        loan.employee.person.id == user.person.id
      end

      can :read, LoanPayment do |loan_payment, user|
        # can read if looking at self
        loan_payment.loan.employee.person.id == user.person.id
      end
    end

    # A user with no role.  In the case of EPS, this
    # user can do nothing
    role :guest do
    end

    # ===================
  end
end
