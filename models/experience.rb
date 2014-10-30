class Experience < ActiveRecord::Base
  include Linkedinable

  belongs_to :job_seeker
  belongs_to :location
  belongs_to :company
  belongs_to :job_category
  belongs_to :job_function

  has_many :experience_skills,
           class_name: 'ExperienceSkill',
           foreign_key: 'experience_id',
           dependent: :destroy
  has_many :skills, through: :experience_skills
  belongs_to :location

  # initialize relations for nested forms
  after_initialize do
    build_location unless location.present?
    build_company unless company.present?
  end

  validates :title, length: { maximum: 200 }
  validates :career_level,
            length: { maximum: 40 },
            format: { with: /\A[_a-z0-9]+\z/ },
            allow_blank: true
  validates :employment_type,
            length: { maximum: 40 },
            format: { with: /\A[_a-z0-9]+\z/ },
            allow_blank: true
  validates :industry,
            length: { maximum: 40 },
            format: { with: /\A[_a-z0-9]+\z/ },
            allow_blank: true
  validates :is_current_position, inclusion: { in: [true, false] }
  validates :objective, length: { maximum: 4000 }

  accepts_nested_attributes_for :location
  accepts_nested_attributes_for :company

  scope :order_by_id, -> { order('id ASC') }

  def display_period
    [display_started_at, display_finished_at].reject(&:blank?).join(' — ')
  end

  def display_started_at
    started_at.try(:strftime, '%B %Y')
  end

  def display_finished_at
    return unless finished_at
    finished_at_month = finished_at.to_date.beginning_of_month
    current_month = Time.now.to_date.beginning_of_month
    if (finished_at_month >= current_month) || is_current_position
      'Present'
    else
      finished_at.try(:strftime, '%B %Y')
    end
  end

  # check if all required fields of experience are completed
  # some of them may be empty after linkedin import
  def completed?
    required_values = [
      title, career_level, employment_type, started_at, finished_at, objective,
      job_category_id, job_function_id, industry
    ]
    # remove all completed fields and check if empty fields left
    required_values_satisfied = (required_values.reject(&:present?).count == 0)
    # related entities dependencies
    skills_satisfied = (experience_skills.count >= 3)
    company_satisfied = (company.present?)

    (required_values_satisfied && skills_satisfied && company_satisfied)
  end

  def self.prefill_from_linkedin(parsed)
    return [] unless parsed.fetch('positions', {})['all'].present?
    parsed['positions']['all'].map do |v|
      next unless v.fetch('company', {})['name'].present?
      create(
        company_attributes: {
          name: v['company']['name'].try(:truncate, 250),
          api_id: v['company']['id'],
          vendor: Company::VENDOR_LINKEDIN_IMPORT
        },
        title: v['title'].try(:truncate, 250),
        objective: v['summary'].try(:truncate, 4000),
        is_current_position: v['is_current'],
        started_at: Linkedinable.linkedin_year(v, 'start_date'),
        finished_at: Linkedinable.linkedin_year(v, 'end_date')
        )
    end
  end

  def self.career_levels
    TextData::Base.career_levels.invert
  end

  def self.employment_types
    TextData::Base.employment_types.invert
  end

  def self.industries
    TextData::Base.industries.invert
  end

  def self.years
    (1900..(DateTime.now.year + 20)).to_a.reverse
  end
end
