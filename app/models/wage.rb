class Wage < ApplicationRecord

  validates :basewage, :basewageb, :basewagec,
           :basewaged, :basewagee, presence: { message: I18n.t(:Not_blank)}

  def readonly?
    # Can be edited, no new ones created.
    new_record? ? true : false
  end
  # no deletes either
  before_destroy { |record| raise ActiveRecord::ReadOnlyRecord }

  # TODO: this is gross
  def self.find_wage(input_category, input_echelon)
    lookup_category = word_to_int(input_category)
    lookup_echelon, lookup_echelonalt = echelon_find(input_echelon)

    wage = Wage.find_by(
          category: lookup_category,
          echelon: lookup_echelon,
          echelonalt: lookup_echelonalt)
    return wage
  end

  def self.echelon_find(input_echelon)
    if (/^[a|b|c|d|e|f]$/ =~ input_echelon)
      return input_echelon, letter_to_ordinal(input_echelon)
    else
      return ordinal_to_letter(word_to_int(input_echelon)), word_to_int(input_echelon)
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

  def self.word_to_int(word)
    lookup = { "one" => 1, "two" => 2, "three" => 3, "four" => 4, "five" => 5,
      "six" => 6, "seven" => 7, "eight" => 8, "nine" => 9, "ten" => 10,
      "eleven" => 11, "twelve" => 12, "thirteen" => 13 }

    lookup[word]
  end

end
