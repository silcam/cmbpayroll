class Add2017Holidays < ActiveRecord::Migration[5.1]

  HOLIDAYS = [{name: "Independence Day", date: '2017-01-01'},
              {name: "Youth Day", date: '2017-02-11'},
              {name: "Labor Day", date: '2017-05-01'},
              {name: "National Day", date: '2017-05-20'},
              {name: "Assumption", date: '2017-08-15'},
              {name: "Christmas", date: '2017-12-25'},
              {name: "Eid ul-Adha", date: '2017-09-01'},
              {name: "Muhammad's Birthday", date: '2017-12-01'},
              {name: "Good Friday", date: '2017-04-14'},
              {name: "Easter", date: '2017-04-16'},
              {name: "Ascension", date: '2017-05-25'},
              {name: "Eid ul-Fitr", date: '2017-06-26'}]

  def up
    HOLIDAYS.each do |params|
      Holiday.create!(params)
    end
  end

  def down
    HOLIDAYS.each do |params|
      Holiday.find_by(params).try(:destroy)
    end
  end
end
