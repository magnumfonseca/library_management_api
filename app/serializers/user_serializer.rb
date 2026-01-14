class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_jsonapi
    {
      data: {
        type: "users",
        id: @user.id.to_s,
        attributes: {
          email: @user.email,
          name: @user.name,
          role: @user.role
        }
      }
    }
  end

  def self.collection(users)
    {
      data: users.map { |user| new(user).as_jsonapi[:data] }
    }
  end
end
