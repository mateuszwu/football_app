I18n::Backend::Simple.include(I18n::Backend::Pluralization)

Rails.application.config.after_initialize do
  I18n.backend.store_translations(:pl, i18n: {
    plural: {
      keys: [ :one, :few, :many, :other ],
      rule: lambda do |count|
        mod10 = count % 10
        mod100 = count % 100

        next :one if count == 1
        next :few if mod10.between?(2, 4) && !mod100.between?(12, 14)
        next :many if count.zero? || mod10 == 1 || mod10.between?(5, 9) || mod100.between?(12, 14)

        :other
      end
    }
  })
end
