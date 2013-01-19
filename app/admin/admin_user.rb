ActiveAdmin.register AdminUser do
  index do
    column :email
    column :guid
    column :current_sign_in_at
    column :last_sign_in_at
    column :sign_in_count
    default_actions
  end

  filter :email

  form do |f|
    f.inputs "Admin Details" do
      f.input :guid
      f.input :email
    end
    f.actions
  end
end
