local economy = {
    balance_rub = 100000,
    currency = "RUB", -- "RUB" или "USD"
    rate = 100 -- 100 руб = $1
}

function economy.getBalance()
    return economy.balance_rub
end

function economy.format(amountRub)
    if economy.currency == "RUB" then
        return string.format("%d ₽", amountRub or 0)
    else
        return string.format("$%d", math.floor((amountRub or 0) / economy.rate))
    end
end

function economy.getBalanceFormatted()
    return economy.format(economy.balance_rub)
end

function economy.toggleCurrency()
    economy.currency = (economy.currency == "RUB") and "USD" or "RUB"
end

function economy.add(amount)
    economy.balance_rub = math.max(0, economy.balance_rub + amount)
end

function economy.canAfford(amount)
    return economy.balance_rub >= amount
end

function economy.spend(amount)
    if economy.canAfford(amount) then
        economy.balance_rub = economy.balance_rub - amount
        return true
    end
    return false
end

function economy.bailout()
    economy.balance_rub = economy.balance_rub + 100000
end

return economy
