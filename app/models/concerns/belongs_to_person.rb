module BelongsToPerson
  extend ActiveSupport::Concern

  included do
    belongs_to :person, autosave: true, validate: true

    default_scope { joins(:person).order('people.last_name, people.first_name') }

    person_methods = [:first_name,
                      :first_name=,
                      :last_name,
                      :last_name=,
                      :full_name,
                      :full_name_rev,
                      :birth_date,
                      :birth_date=,
                      :gender,
                      :gender=]

    person_methods.each do |method|
      define_method method do |*args|
        person.send(method, *args)
      end
    end
  end

  module ClassMethods
    def new_with_person(params={})
      self.new params
    end

    def new(params={})
      newguy = super(person: Person.new)
      newguy.assign_attributes params
      newguy
    end
  end



  # def first_name
  #   person.first_name
  # end
  #
  # def last_name
  #   person.last_name
  # end
  #
  # def birth_date
  #   person.birth_date
  # end
  #
  # def gender
  #   person.gender
  # end
  #
  # def full_name
  #   person.full_name
  # end
  #
  # def full_name_rev
  #   person.full_name_rev
  # end

end