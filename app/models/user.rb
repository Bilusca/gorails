# app/models/user.rb
# Model user generated by Devise
class User < ActiveRecord::Base
  include PublicActivity::Model
  tracked owner: ->(controller, model) {controller && controller.current_user}
  rolify

  has_many :rewards, class_name: 'Gamification::Reward', as: :rewardable
  has_many :goals, through: :rewards, class_name: 'Gamification::Goal'
  belongs_to :inventory, class_name: 'Gamification::Inventory'

  def medals
    rewards.includes(goal: :medal).collect(&:medal).compact || []
  end


  def level
    level = Gamification::Level.where('gamification_levels.experience = (select max(gamification_levels.experience)
       FROM gamification_levels where experience < ?)', self.current_experience).first
    if level
      level.level
    else
      1
    end
  end

  def next_level_xp
    Gamification::Level.where(level: level + 1).first.experience
  end

  def current_experience
    goals.sum(:points)
  end

  def current_rubys
    goals.sum(:rubys)
  end

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :trackable,
         :validatable,
         :omniauthable

  HUMANIZED_ATTRIBUTES = {
      id: "Usuario",
      email: "E-mail",
      password: "Senha",
      password_confirmation: "Confirmação de Senha",
      remember_me: "Lembrar-me",
      current_password: 'Senha Atual',
      first_name: 'Primeiro Nome',
      last_name: 'Ultimo Nome',
      cpf: "CPF",
      nickname: "Nickname",
      bio: "Biografia",
      company: "Empresa/Instituição de Ensino",
      gender: "Sexo",
      job_title: "Cargo/Função",
      phone: "Telefône(Fixo)",
      celphone: "Telefône(Celular)",
      schooling: "Escolaridade",
      birth_date: "Data de nascimento",
      marital_status: "Estado civil",
      father: "Filiação(Pai)",
      mother: "Filiação(Mãe)",
      consignor_organ: "Órgão Expedidor",
      place_of_birth: "Naturalidade",
      special_needs: "Necessidades Especiais: (Física, Mental, Visual, Auditiva ou Nenhuma)",
      occupation: "Situação Ocupacional",
      rg: "Identidade",
      address: "Endereço",
      geography_state_id: "UF",
      neighborhood: "Bairro",
      zip_code: "CEP",
      complement: "Complemento",
      reset_password_token: "Token"
  }

  #def admin?
  # self.admin == true
  #end
  has_many :winners
  # validates :terms_of_service, acceptance: true
  has_many :registrations
  has_many :social_networks
  validate :unicidade_cpf
  usar_como_cpf :cpf

  validates_presence_of :first_name, :last_name, :cpf, :rg, :consignor_organ, :company, :phone, :celphone, :schooling, :birth_date, :gender, :marital_status, :place_of_birth, :mother, :address, :neighborhood, :geography_state_id, :zip_code, :special_needs, :complement, if: lambda {self.need_certificate.present?}

  has_many :attachments, as: :origin
  mount_uploader :avatar, AttachmentsUploader
  mount_uploader :cover_photo, AttachmentsUploader
  accepts_nested_attributes_for :attachments
  accepts_nested_attributes_for :social_networks, reject_if: proc {|a| a[:link].blank?}, allow_destroy: true

  before_save :phone_numeric

  def phone_numeric
    self.celphone = celphone.gsub(/\D/, '') if celphone.present?
    self.phone = phone.gsub(/\D/, '') if phone.present?
  end

  def name
    [first_name, last_name].join(" ").strip
  end

  def self.human_attribute_name(attr, vazio=nil)
    HUMANIZED_ATTRIBUTES[attr.to_sym] || super
  end

  # Generate csv from all atributes of user
  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      lista = []
      column_names.each {|coluna| lista << self.human_attribute_name(coluna)}
      csv << lista
      all.each {|registro| csv << registro.attributes.values_at(*column_names)}
    end
  end

  # Verify if cpf attribute is valid
  def has_valid_cpf?
    self.cpf.valido?
  end

  def unicidade_cpf
    if self.cpf.present? && User.where(cpf: self.cpf).where("id <> ?", self.id || 0).first
      errors.add(:cpf, "já está em uso")
    end
  end

  def need_updated_account?
    self.cpf.nil? || self.first_name.nil? || self.last_name.nil?
  end

  def self.from_omniauth(access_token)
    validates :email, presence: false, email: false

    provider = access_token.provider
    data = access_token.extra.raw_info
    user = User.find_by(email: data.email)

    unless user
      user = User.new
      user.first_name ||= data.first_name
      user.last_name ||= data.last_name
      user.nickname ||= data.nickname
      user.email = data.email
      user.password = Devise.friendly_token[0, 20]
      user.provider = provider
      user.uid = access_token.uid
      user.save
    end
    user.avatar.download!(data.picture)
    user
  end

  #Returns a full name of user, a combination of first name and last name
  def full_name
    if (first_name && last_name) && (!first_name.blank? && !last_name.blank?)
      " #{first_name} #{last_name}"
    else
      " #{nickname}"
    end
  end

  #Returns a first name of user, if it is blank return first part of email
  def event_name
    if first_name && !first_name.blank?
      " #{first_name}"
    else
      " #{nickname}"
    end
  end

  def data_completed
    return true if self.rg.present? &&
        self.consignor_organ.present? &&
        self.company.present? &&
        self.phone.present? &&
        self.celphone.present? &&
        self.schooling.present? &&
        self.birth_date.present? &&
        self.gender.present? &&
        self.marital_status.present? &&
        self.place_of_birth.present? &&
        self.mother.present? &&
        self.address.present? &&
        self.neighborhood.present? &&
        self.geography_state_id.present? &&
        self.zip_code.present? &&
        self.special_needs.present? &&
        self.complement.present?
  end

  def admin?
    roles.first.name.to_sym == :admin if roles.first.present?
  end
end
