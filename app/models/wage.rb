include ApplicationHelper

class Wage < ApplicationRecord

  INVALID_WAGE = -1

  validates :basewage, :basewageb, :basewagec,
           :basewaged, :basewagee, presence: { message: I18n.t(:Not_blank)}

  @wage_by_scale = {
    "a" => "basewage",
    "b" => "basewageb",
    "c" => "basewagec",
    "d" => "basewaged",
    "e" => "basewagee"
  }

  def readonly?
    # Can be edited, no new ones created.
    new_record? ? true : false
  end
  # no deletes either
  before_destroy { |record| raise ActiveRecord::ReadOnlyRecord }

  def self.find_wage(input_category, input_echelon, input_scale)
    lookup_category = ::ApplicationHelper.word_to_int(input_category)
    lookup_echelon, lookup_echelonalt = echelon_find(input_echelon)

    wage = Wage.find_by(
          category: lookup_category,
          echelon: lookup_echelon,
          echelonalt: lookup_echelonalt)

    input_scale = "a" if (input_scale.nil?)
    return INVALID_WAGE if (wage.nil?)

    scaled_wage = wage.send(@wage_by_scale[input_scale])
    return INVAILD_WAGE if (scaled_wage <= 0)

    scaled_wage
  end

  def self.echelon_find(input_echelon)
    if (/^[a|b|c|d|e|f]$/ =~ input_echelon)
      return input_echelon, letter_to_ordinal(input_echelon)
    else
      return ordinal_to_letter(
          ::ApplicationHelper.word_to_int(input_echelon)
            ), ::ApplicationHelper.word_to_int(input_echelon)
    end
  end

  private

  def self.ordinal_to_letter(ordinal)
    lookup = { 1 => "a", 2 => "b", 3 => "c", 4 => "d", 5 => "e", 6 => "f" }

    result = lookup[ordinal]
    if result
      return result
    else
      return "-"
    end
  end

  def self.letter_to_ordinal(letter)
    lookup = { "a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5, "f" => 6 }

    result = lookup[letter]
  end

end
