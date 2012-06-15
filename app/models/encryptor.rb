class Encryptor
  def initialize(default = '')
    @default = default
  end

  def cipher
    @cipher ||= ::Gibberish::AES.new(APP_CONFIG['encryption_key'])
  end

  def load(s)
    s.present? ? cipher.dec(s) : @default.clone
  end

  def dump(s)
    cipher.enc(s || @default)
  end
end
