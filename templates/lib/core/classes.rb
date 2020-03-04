# Add convenient method to reference secrets.
# Would be nice for parameter store as well!
class String
  def secret(argument)
    [
      "{{resolve:secretsmanager:",
      self.ref,
      ":SecretString:",
      argument,
      "}}"
    ].fnjoin
  end
end

class Symbol
  def secret(argument)
    [
      "{{resolve:secretsmanager:",
      self.ref,
      ":SecretString:",
      argument,
      "}}"
    ].fnjoin
  end
end
