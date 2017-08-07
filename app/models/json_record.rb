class JSONRecord
  include ActiveModel::Model
  include ActiveModel::Serializers::JSON

  def save
    if valid?
      return true
    else
      return false
    end
  end
end
