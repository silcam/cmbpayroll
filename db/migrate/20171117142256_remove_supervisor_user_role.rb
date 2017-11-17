class RemoveSupervisorUserRole < ActiveRecord::Migration[5.1]
  def up
    User.where("role=1").update(role: :user)
  end

  def down
    # Can't, sorry
  end
end
