module Fixy
  module Formatter
    module RjustAlphanumeric
      def format_rjust_alpha(input, length)
        input = input.to_s
        raise ArgumentError, "Invalid Input (digits and numbers are accepted, not #{input})" unless input =~ /^[-a-zA-Z0-9' ]+$/
        raise ArgumentError, "Not enough length (input: #{input}, length: #{length})" if input.length > length
        input.rjust(length, ' ')
      end
    end
  end
end
