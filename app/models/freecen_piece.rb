class FreecenPiece
  include Mongoid::Document
  field :chapman_code, type: String
  field :piece_number, type: Integer
  field :district_name, type: String
  field :subplaces, type: Array
  field :subplaces_sort, type: String
  field :parish_number, type: String
  field :suffix, type: String
  field :year, type: String
  field :status, type: String
  field :remarks, type: String
  field :online_time, type: Integer
  field :num_individuals, type: Integer, default: 0
  belongs_to :freecen1_fixed_dat_entry
  belongs_to :place
  has_many :freecen_dwellings
  
  index(:piece_number => 1, :chapman_code => 1)
  index(:piece_number => 1, :chapman_code => 1, :year => 1, :suffix => 1)
end
