local config = {
    team = "Pirates", --? Pirates Marines
    servertohop = "Singapore",
    timetoskip = 80,
    timetohop = 600,
    autouselowgraphic = true,
    autoQ = false,
    random = true, --! random = false if u want to use custom
    autoken = true,
    enablev4 = true,
    enablev3 = true,
    blackscreen = false,
    ignorefruits = {"Portal-Portal"--[[, "Buddha-Buddha", "Dragon-Dragon", "Kitsune-Kitsune", "Leopard-Leopard"]]},
    safezone = {
        HighestHealth = 65, -- % health
        LowestHealth = 35, -- % health
    },
    methodclicks = {
        LowerHealthToM1 = 2000,
        Delay = 0.3,
        Melee = true,
        Sword = true,
        Gun = false,
    },
    custom = {
        Melee = {
            Enable = true,
            Skills = {
                Z = {
                    Enable = true,
                    Number = 3,
                    0.2222,
                },
                X = {
                    Enable = true,
                    Number = 5,
                    0.2222,
                },
                C = {
                    Enable = true,
                    Number = 4,
                    0.2222,
                },
            },
        },
        Sword = {
            Enable = true,
            Skills = {
                Z = {
                    Enable = true,
                    Number = 1,
                    0.2222,
                },
                X = {
                    Enable = true,
                    Number = 2,
                    0.2222,
                },
            },
        },
        ['Blox Fruit'] = {
            Enable = false,
            Skills = {
                Z = {
                    Enable = true,
                    Number = 4,
                    0.2222,
                },
                X = {
                    Enable = true,
                    Number = 1,
                    0.2222,
                },
                C = {
                    Enable = true,
                    Number = 4.5,
                    0.2222,
                },
                V = {
                    Enable = true,
                    Number = 7,
                    0.2222,
                },
                F = {
                    Enable = true,
                    Number = 8,
                    0.2222,
                },
            },
        },
        Gun = {
            Enable = false,
            Skills = {
                Z = {
                    Enable = true,
                    Number = 5,
                    0.2222,
                },
                X = {
                    Enable = true,
                    Number = 1,
                    0.2222,
                },
            },
        },
    },
    webhook = {
        Enabled = true,
        Url = "",
    }
}

_G.mergeConfig(config, _G.config)
warn("Loaded config")
return config
