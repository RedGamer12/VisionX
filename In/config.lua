
local config = {
    team = "Pirates", -- Pirates Marines
    servertohop = "Singapore",
    timetoskip = 60,
    timetohop = 350,
    autouselowgraphic = true,
    autoQ = true,
    random = true, --! random = false if u want to use custom
    autoken = false,
    enablev4 = true,
    enablev3 = true,
    blackscreen = true,
    ignorefruits = {"Portal-Portal", "Buddha-Buddha", "Dragon-Dragon", "Kitsune-Kitsune", "Leopard-Leopard"},
    safezone = {
        HighestHealth = 75,
        LowestHealth = 55,
    },
    teleport = {
        helicopter = 150, --! >= 100
        instant = 180,
        speed = 295,
    },
    methodclicks = {
        Melee = true,
        LowerHealthToM1 = 7000,
        Gun = false,
        Sword = true,
        Delay = 0.1,
        attack = { startupDelay = 0.1, loopInterval = 0.751, perTargetDelay = 0.0 }
    },
    custom = {
        Melee = {
            Enable = true,
            Skills = {
                Z = {
                    Enable = true,
                    Number = 3,
                    HoldTime = 0.152,
                },
                X = {
                    Enable = true,
                    Number = 5,
                    HoldTime = 0.152,
                },
                C = {
                    Enable = true,
                    Number = 4,
                    HoldTime = 0.152,
                },
            },
        },
        Sword = {
            Enable = true,
            Skills = {
                Z = {
                    Enable = true,
                    Number = 1,
                    HoldTime = 0.152,
                },
                X = {
                    Enable = true,
                    Number = 2,
                    HoldTime = 0.152,
                },
            },
        },
        ['Blox Fruit'] = {
            Enable = true,
            Skills = {
                Z = {
                    Enable = true,
                    Number = 4,
                    HoldTime = 0.152,
                },
                X = {
                    Enable = true,
                    Number = 1,
                    HoldTime = 0.152,
                },
                C = {
                    Enable = true,
                    Number = 4.5,
                    HoldTime = 0.152,
                },
                V = {
                    Enable = true,
                    Number = 7,
                    HoldTime = 0.152,
                },
                F = {
                    Enable = true,
                    Number = 8,
                    HoldTime = 0.152,
                },
            },
        },
        Gun = {
            Enable = false,
            Skills = {
                Z = {
                    Enable = true,
                    Number = 5,
                    HoldTime = 0.152,
                },
                X = {
                    Enable = true,
                    Number = 1,
                    HoldTime = 0.152,
                },
            },
        },
    },
    webhook = {
        Enabled = false,
        Url = "",
    }
}

_G.mergeConfig(config, _G.config)
warn("Loaded config")
return config
