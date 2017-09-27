include ActionView::Helpers::DateHelper

class PayrollAudit

  def self.feed_items
    feed_items = Array.new

    Audited::Audit.all.reorder(:created_at => :desc).limit(10).each do |item|
      item_hash = Hash.new
      item_hash[:title] = "#{item.auditable_type} #{item.action}"

      if (item.auditable_type == "Employee")
        person = Employee.find(item.auditable_id)
        if (item.action == "create")
          item_hash[:text] = "#{person.full_name} was created."
        elsif (item.action == "update")
          item_hash[:text] = "#{person.full_name} was edited.  Fields modified: #{item.audited_changes.keys}"
        elsif (item.action == "delete")
          item_hash[:text] = "#{person.full_name} was deleted."
        end
      end

      item_hash[:who] = User.find(item.user_id).full_name
      item_hash[:when] =  "#{time_ago_in_words(item.created_at)} ago"

      feed_items << item_hash
    end
    feed_items
  end
end
