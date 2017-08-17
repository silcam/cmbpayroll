json.extract! child, :id, :first_name, :last_name, :birth_date, :is_student, :created_at, :updated_at
json.url child_url(child, format: :json)
