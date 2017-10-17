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
    end

    # An employee can perform limited administration
    # on herself.
    role :self do
      # permissions go here

      can :read, Employee do |employee, user|
        # can read if looking at self
        employee.person.id == user.person.id
      end
    end

    # A user with no role.  In the case of EPS, this
    # user can do nothing
    role :guest do
      # permissions go here
    end

    # ===================
  end
end
