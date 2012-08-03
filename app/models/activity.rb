class Activity < ActiveRecord::Base
  belongs_to :account_list
  has_many :activity_contacts, dependent: :destroy
  has_many :contacts, through: :activity_contacts
  has_many :activity_comments, dependent: :destroy
  has_many :people, through: :activity_comments

  scope :overdue, where('start_at < ?', Time.now).order('start_at')
  scope :tomorrow, where("start_at BETWEEN ? AND ?", Time.now, 1.day.from_now).order('start_at')
  scope :upcoming, where("start_at > ?", 1.day.from_now).order('start_at')
  scope :completed, where(completed: true).order('start_at desc')
  scope :uncompleted, where(completed: false).order('start_at')
  scope :starred, where(starred: true).order('start_at')


  accepts_nested_attributes_for :activity_contacts, :activity_comments, allow_destroy: true

  attr_accessible :starred, :location, :subject, :start_at, :end_at, :completed,
                  :activity_contacts_attributes, :activity_comments_attributes,
                  :contacts_attributes

  validates :subject, :start_at, presence: true

  def to_s() subject; end

  def contacts_attributes=(contacts_array)
    contacts_array = contacts_array.values if contacts_array.is_a?(Hash)
    contacts_array.each do |contact_attributes|
      contact = Contact.find(contact_attributes['id'])
      if contact_attributes['_destroy'].to_s == 'true'
        contacts.delete(contact) if contacts.include?(contact)
      else
        contacts << contact unless contacts.include?(contact)
      end
    end
  end

end
