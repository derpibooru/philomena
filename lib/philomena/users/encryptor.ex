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

  def encrypt_model(secret) do
    salt = :crypto.strong_rand_bytes(16)
    iv = :crypto.strong_rand_bytes(12)

    {:ok, key} = :pbkdf2.pbkdf2(:sha, otp_secret(), salt, 2000, 32)
    {msg, auth_tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, secret, "", true)

    # attr_encrypted encoding scheme
    %{
      secret: Base.encode64(<<msg::binary, auth_tag::binary>>) <> "\n",
      salt: "_" <> Base.encode64(salt) <> "\n",
      iv: Base.encode64(iv) <> "\n"
    }
  end

  defp otp_secret do
    Application.get_env(:philomena, :otp_secret_key)
  end
end
