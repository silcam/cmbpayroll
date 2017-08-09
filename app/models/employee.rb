class Employee < JSONBackedModel

  define_attributes [:first_name, :last_name, :title, :name, :department]

  has_many :transactions

  validates :first_name, :last_name, presence: {message: I18n.t(:Not_blank)}

  def full_name
    "#{@first_name} #{@last_name}"
  end

  def full_name_rev
    "#{@last_name}, #{@first_name}"
  end

  def self.mock_service_class
    MockEmployeeService
  end

end
