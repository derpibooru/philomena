defmodule Philomena.Users.Encryptor do
  def decrypt_model(secret, iv, salt) do
    # attr_encrypted encoding scheme
    secret = Base.decode64!(secret, ignore: :whitespace)
    iv = Base.decode64!(iv, ignore: :whitespace)
    <<?_, salt::binary>> = salt
    salt = Base.decode64!(salt, ignore: :whitespace)

    {:ok, key} = :pbkdf2.pbkdf2(:sha, otp_secret(), salt, 2000, 32)
    auth_tag = :binary.part(secret, byte_size(secret), -16)
    msg = :binary.part(secret, 0, byte_size(secret) - 16)

    :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, msg, "", auth_tag, false)
  end

  defp otp_secret do
    Application.get_env(:philomena, :otp_secret_key)
  end
end
