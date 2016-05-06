# app/models/user.rb
# Model user generated by Devise
class User < ActiveRecord::Base
  include PublicActivity::Model
  tracked owner: ->(controller, model) { controller && controller.current_user }
  rolify
  acts_as_commontator
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable


  HUMANIZED_ATTRIBUTES = {
      :id => "Usuario",
      :email => "E-mail",
      :password => "Senha",
      :password_confirmation => "Confirmação de Senha",
      :remember_me => "Lembrar-me",
      :current_password => 'Senha Atual',
      :first_name => 'Primeiro Nome',
      :last_name => 'Ultimo Nome',
      :cpf => "CPF",
      :nickname => "Nickname",
      :bio => "Biografia",
      :company => "Empresa/Instituição de Ensino",
      :gender => "Sexo",
      :job_title => "Cargo/Função",
      :phone => "Telefône(Fixo)",
      :celphone => "Telefône(Celular)",
      :schooling => "Escolaridade",
      :birth_date => "Data de nascimento",
      :marital_status => "Estado civil",
      :father => "Filiação(Pai)",
      :mother => "Filiação(Mãe)",
      :consignor_organ => "Órgão Expedidor",
      :place_of_birth => "Naturalidade",
      :special_needs => "Necessidades Especiais: (Física, Mental, Visual, Auditiva ou Nenhuma)",
      :occupation => "Situação Ocupacional",
      :rg => "Identidade",
      :address => "Endereço",
      :uf => "UF",
      :neighborhood => "Bairro",
      :zip_code => "CEP",
      :complement => "Complemento",
      :city => "Cidade",
      :receber_email => "Receber E-mail da GoRails",
      :receber_email_parceiros => "Receber E-mail de Parceiros"
  }

  #def admin?
  # self.admin == true
  #end
  has_many :winners
  # validates :terms_of_service, acceptance: true
  has_many :registrations
  validate :unicidade_cpf
  usar_como_cpf :cpf

  validates_presence_of :first_name, :last_name, :cpf, :rg, :consignor_organ, :company, :phone, :celphone, :schooling, :birth_date, :gender, :marital_status, :place_of_birth, :mother, :address, :neighborhood, :uf, :zip_code, :special_needs, :complement, :city, :if => lambda { self.need_certificate.present? }

  has_many :attachments, as: :origin
  mount_uploader :avatar, AttachmentsUploader
  mount_uploader :cover_photo, AttachmentsUploader
  accepts_nested_attributes_for :attachments


  def self.human_attribute_name(attr, vazio=nil)
    HUMANIZED_ATTRIBUTES[attr.to_sym] || super
  end

  # Generate csv from all atributes of user
  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      lista = []
      column_names.each { |coluna| lista << self.human_attribute_name(coluna) }
      csv << lista
      all.each { |registro| csv << registro.attributes.values_at(*column_names) }
    end
  end

  # Verify if cpf attribute is valid
  def has_valid_cpf?
    self.cpf.valido?
  end

  def unicidade_cpf
    if self.cpf.present? and User.where(:cpf => self.cpf).where("id <> ?", self.id || 0).first
      errors.add(:cpf, "já está em uso")
    end
  end

  def need_updated_account?
    self.cpf.nil? or self.first_name.nil? or self.last_name.nil?
  end

  def self.from_omniauth(access_token)
    provider = access_token.provider
    data = access_token.info
    user = User.where(:email => data["email"]).first

    unless user
      user = User.new
      user.first_name ||= data["first_name"]
      user.last_name ||= data["last_name"]
      user.nickname ||= data["nickname"]
      user.email = data["email"]
      user.password = Devise.friendly_token[0, 20]
      user.provider = provider
      user.uid = access_token.uid
      user.save
    end
    user.avatar.download!(data["image"])
    user
  end

  #Returns a full name of user, a combination of first name and last name
  def full_name
    if (first_name and last_name) and (!first_name.blank? and !last_name.blank?)
      " #{first_name} #{last_name}"
    else
      " #{email.split('@')[0]}"
    end
  end

  #Returns a first name of user, if it is blank return first part of email
  def event_name
    if first_name and !first_name.blank?
      " #{first_name}"
    else
      " #{email.split('@')[0]}"
    end
  end

  def data_completed
    return true if self.rg.present? and
        self.consignor_organ.present? and
        self.company.present? and
        self.phone.present? and
        self.celphone.present? and
        self.schooling.present? and
        self.birth_date.present? and
        self.gender.present? and
        self.marital_status.present? and
        self.place_of_birth.present? and
        self.mother.present? and
        self.address.present? and
        self.neighborhood.present? and
        self.uf.present? and
        self.zip_code.present? and
        self.special_needs.present? and
        self.city.present? and
        self.complement.present?
  end

end
