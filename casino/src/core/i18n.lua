local i18n = {}
i18n.current = "en"

local okRu, ru = pcall(require, "locales.ru")
local okEn, en = pcall(require, "locales.en")

i18n.locales = {
    ru = okRu and ru or {},
    en = okEn and en or {}
}

function i18n.setLanguage(lang)
    if i18n.locales[lang] then
        i18n.current = lang
    end
end

function i18n.toggle()
    i18n.current = (i18n.current == "ru") and "en" or "ru"
end

function i18n.t(key)
    local dict = i18n.locales[i18n.current]
    return (dict and dict[key]) or key
end

return i18n
