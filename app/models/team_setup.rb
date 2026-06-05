class TeamSetup < ApplicationRecord
  belongs_to :match_day
  has_many :teams, dependent: :destroy
end
