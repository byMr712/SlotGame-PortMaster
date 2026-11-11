local economy = {
    balance = 10000,
    currency = "USD"
}

function economy.getBalance()
    return economy.balance
end

function economy.format(amount)
    local n = math.floor(amount or 0)
    local s = tostring(math.abs(n))
    local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    if n < 0 then
        return string.format("-$%s", formatted)
    else
        return string.format("$%s", formatted)
    end
end

function economy.getBalanceFormatted()
    return economy.format(economy.balance)
end

function economy.toggleCurrency()
    -- Strict USD standard
    economy.currency = "USD"
end

function economy.add(amount)
    economy.balance = math.max(0, economy.balance + (amount or 0))
end

function economy.canAfford(amount)
    return economy.balance >= (amount or 0)
end

function economy.spend(amount)
    if economy.canAfford(amount) then
        economy.balance = economy.balance - amount
        return true
    end
    return false
end

function economy.bailout()
    economy.balance = economy.balance + 10000
end

return economy
